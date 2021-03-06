context("Basic interventions: TSM and ATE for single node interventions.")

library(sl3)
library(uuid)
library(assertthat)
library(data.table)

# setup data for test
data(cpp)
cpp <- cpp[!is.na(cpp[, "haz"]), ]
cpp$parity3 <- cpp$parity
cpp$parity3[cpp$parity3 > 3] <- 3
cpp$parity01 <- as.numeric(cpp$parity > 0)
cpp[is.na(cpp)] <- 0
cpp$haz01 <- as.numeric(cpp$haz > 0)

# define NPSEM as TMLE nodes and create a tmle3_task
tmle_nodes <- list(
  define_node("W", c(
    "apgar1", "apgar5", "gagebrth", "mage",
    "meducyrs", "sexn"
  )),
  define_node("A", c("parity01"), c("W")),
  define_node("Y", c("haz01"), c("A", "W"))
)
task <- tmle_Task$new(cpp, tmle_nodes = tmle_nodes)

# set up sl3 learners for tmle3 fit
lrnr_glm_fast <- make_learner(Lrnr_glm_fast)
lrnr_mean <- make_learner(Lrnr_mean)

# define and fit likelihood
factor_list <- list(
  define_lf(LF_static, "W", NA),
  define_lf(LF_fit, "A", lrnr_glm_fast),
  define_lf(LF_fit, "Y", lrnr_mean)
)

likelihood_def <- Likelihood$new(factor_list)
likelihood <- likelihood_def$train(task)

# define parameter and get TMLE likelihood
intervention <- define_cf(define_lf(LF_static, "A", value = 1))

tsm <- Param_TSM$new(intervention)

lrnr_submodel <- make_learner(Lrnr_glm_fast, intercept = FALSE, transform_offset = TRUE)
tmle_likelihood <- fit_tmle_likelihood(likelihood, task, tsm, lrnr_submodel)

init_ests <- tsm$estimates(likelihood, task)
tmle_ests <- tsm$estimates(tmle_likelihood, task)

# get initial and parameter estimates
tmle3_init_psi <- init_ests$psi
tmle3_tmle_psi <- tmle_ests$psi
ED <- mean(tmle_ests$IC)

# TEST: is the mean of the EIF nearly zero.
expect_lt(abs(ED), 1 / task$nrow)


# TEST: new tmle3 estimates match expected
expected_init_psi <- 0.555170020818876
expected_tmle_psi <- 0.526801368635302
expect_equivalent(tmle3_init_psi, expected_init_psi)
expect_equal(
  tmle3_tmle_psi, expected_tmle_psi, tolerance = 1e-4,
  check.attributes = FALSE
)


cf_a1 <- define_cf(define_lf(LF_static, "A", value = 1))
cf_a0 <- define_cf(define_lf(LF_static, "A", value = 0))
ate <- Param_ATE$new(cf_a0, cf_a1)

tmle_likelihood <- fit_tmle_likelihood(likelihood, task, ate, lrnr_submodel)

init_ests <- ate$estimates(likelihood, task)
init_ests$psi
tmle_ests <- ate$estimates(tmle_likelihood, task)
tmle_ests$psi
ED <- mean(tmle_ests$IC)

# TEST: mean of the EIF is nearly zero.
expect_lt(abs(ED), 1 / task$nrow)
