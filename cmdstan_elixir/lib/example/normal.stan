// Normal distribution parameter estimation
// Estimates mu (mean) and sigma (standard deviation)

data {
  int<lower=0> N;        // number of observations
  vector[N] y;           // observed data
}

parameters {
  real mu;               // mean parameter
  real<lower=0> sigma;   // standard deviation parameter (must be positive)
}

model {
  // priors
  mu ~ normal(0, 10);        // weakly informative prior for mean
  sigma ~ cauchy(0, 5);      // weakly informative prior for std dev

  // likelihood
  y ~ normal(mu, sigma);
}

generated quantities {
  // posterior predictive checks
  vector[N] y_pred;
  for (n in 1:N) {
    y_pred[n] = normal_rng(mu, sigma);
  }
}