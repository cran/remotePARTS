# fitCor() ----

#' @title Estimate spatial parameters from time series residuals
#'
#' @description \code{fitCor()} estimates parameter values of a distance-based
#' variance function from the pixel-wise correlations among time series residuals.
#'
#' @param resids a matrix of time series residuals, with rows corresponding to
#' pixels and columns to time points
#' @param coords a numeric coordinate matrix or data frame, with two columns and
#' rows corresponding to each pixel
#' @param distm_FUN a function to calculate a distance matrix from \code{coords}
#' @param covar_FUN a function to estimate distance-based covariances
#' @param start a named list of starting parameter values for \code{covar_FUN}, passed to \code{nls}
#' @param fit.n an integer indicating how many pixels should be used to estimate parameters.
#' @param index an optional index of pixels to use for parameter estimation
#' @param save_mod logical: should the nls model be saved in the output?
#' @param ... additional arguments passed to \code{nls}.
#'
#' @details
#'
#' For accurate results, \code{resids} and \code{coords} must be paired matrices.
#' Rows of both matrices should correspond to the same pixels.
#'
#' Distances between sapmled pixels are calculated with the function specified by
#' \code{distm_FUN}. This function can be any that takes a coordinate
#' matrix as input and returns a distance matrix between points. Some options
#' provided by \code{remotePARTS} are \code{distm_km()}, which returns distances
#' in kilometers and \code{distm_scaled()}, which returns distances scaled between
#' 0 and 1.
#'
#' \code{covar_FUN} can be any function that takes a vector of distances as its
#' first argument, and at least one parameter as additional arguments. \code{remotePARTS}
#' provides three suitable functions: \code{covar_exp}, \code{covar_exppow}, and
#' \code{covar_taper}; but user-defined functions are also possible.
#'
#' Parameters are estimated with \code{stats::nls()} by regressing correlations
#' among time series residuals on a function of distances specified by \code{covar_FUN}.
#'
#' \code{start} is used by \code{nls} to determine how many parameters need
#' estimating, and starting values for those parameters. As such, it is important
#' that \code{start} has named elements for each parameter in \code{covar_FUN}.
#'
#' The fit will be performed for all pixels specified in \code{index}, if provided.
#' Otherwise, a random sample of length \code{fit.n} is used. If \code{fit.n}
#' exceeds the number of pixels, all pixels are used. When random pixels are used,
#' parameter estimates will be different for each call of the function. For reproducible
#' results, we recommend taking a random sample of pixels manually and passing in
#' those values as \code{index}.
#'
#' Caution: Note that a distance matrix, of size \eqn{n \times n} must be fit to the
#' sampled data where \eqn{n} is either \code{fit.n} or \code{length(index)}.
#' Take your computer's memory and processing time into consideration when choosing
#' this size.
#'
#' Parameter estimates are always returned in the same scale of distances
#' calculated by \code{distm_FUN}. It is very important that these estimates
#' are re-scaled by users if output of \code{distm_FUN} use units different from
#' the desired scale. For example,
#' if the function \code{covar_FUN = function(d, r, a){-(d/r)^a}} is used
#' with \code{distm_FUN = "distm_scaled"}, the estimated range parameter \code{r}
#' will be based on a unit-map. Users will likely want to re-scaled it to map
#' units by multiplying \code{r} by the maximum distance among points on your map.
#'
#' If the \code{distm_FUN} is on the scale of your map (e.g., "distm_km"),
#' re-scaling is not needed but may be preferable, since it is scaled to the
#' maximum distance among the sampled data rather than the true maximum
#' distance. For example, dividing the range parameter by \code{max.distance}
#' and then multiplying it by the true max distance may provide a better range
#' estimate.
#'
#' @return \code{fitCor} returns a list object of class "remoteCor", which contains
#' these elements:
#'
#' \describe{
#'      \item{call}{the function call}
#'      \item{mod}{the \code{nls} fit object, if \code{save_mod=TRUE}}
#'      \item{spcor}{a vector of the estimated spatial correlation parameters}
#'      \item{max.distance}{the maximum distance among the sampled pixels, as calculated by \code{dist_FUN}.}
#'      \item{logLik}{the log-likelihood of the fit}
#' }
#'
#' @examples
#'
#' # simulate dummy data
#' set.seed(19)
#' time.points = 30 # time series length
#' map.width = 8 # square map width
#' coords = expand.grid(x = 1:map.width, y = 1:map.width) # coordinate matrix
#'
#' ## create empty spatiotemporal variables:
#' X <- matrix(NA, nrow = nrow(coords), ncol = time.points) # response
#' Z <- matrix(NA, nrow = nrow(coords), ncol = time.points) # predictor
#'
#' ## setup first time point:
#' Z[, 1] <- .05*coords[,"x"] + .2*coords[,"y"]
#' X[, 1] <- .5*Z[, 1] + rnorm(nrow(coords), 0, .05) #x at time t
#'
#' ## project through time:
#' for(t in 2:time.points){
#'   Z[, t] <- Z[, t-1] + rnorm(map.width^2)
#'   X[, t] <- .2*X[, t-1] + .1*Z[, t] + .05*t + rnorm(nrow(coords), 0 , .25)
#' }
#'
#' AR.map = fitAR_map(X, coords, formula = y ~ Z, X.list = list(Z = Z), resids.only = FALSE)
#'
#' # using pre-defined covariance function
#' ## exponential covariance
#' fitCor(AR.map$residuals, coords, covar_FUN = "covar_exp", start = list(range = .1))
#'
#' ## exponential-power covariance
#' fitCor(AR.map$residuals, coords, covar_FUN = "covar_exppow", start = list(range = .1, shape = .2))
#'
#' # user-specified covariance function
#' fitCor(AR.map$residuals, coords, covar_FUN = function(d, r){d^r}, start = list(r = .1))
#'
#' # un-scaled distances:
#' fitCor(AR.map$residuals, coords, distm_FUN = "distm_km", start = list(r = 106))
#'
#' # specify which pixels to use, for reproducibility
#' fitCor(AR.map$residuals, coords, index = 1:64)$spcor #all
#' fitCor(AR.map$residuals, coords, index = 1:20)$spcor #first 20
#' fitCor(AR.map$residuals, coords, index = 21:64)$spcor # last 43
#' # randomly select pixels
#' fitCor(AR.map$residuals, coords, fit.n = 20)$spcor #random 20
#' fitCor(AR.map$residuals, coords, fit.n = 20)$spcor # different random 20
#'
#' @export
fitCor <- function(resids, coords, distm_FUN = "distm_scaled", covar_FUN = "covar_exp",
                   start = list(r = .1), fit.n = 1000, index, save_mod = TRUE, ...
                   ){
  call = match.call()

  stopifnot(nrow(resids) == nrow(coords))

  # match distance function
  dist.f = match.fun(distm_FUN)
  # set covar function conditionally
  covar.f = if (length(call[["covar_FUN"]]) > 1) {
    ## if a function is provided in-line
    c.fun = match.fun(covar_FUN) # match the function
    "c.fun" # and set covar.f to this matched name
  } else {
    ## if covar_FUN is a character string or function name
    deparse(substitute(covar_FUN)) # set covar.f to that string
  }

  # subset the pixels for fit
  if (!missing(index)){ # specified pixels
    sub.inx = index
  } else { # random pixels
    # dimensions
    n = nrow(resids)
    fit.n = min(fit.n, n)  # prevent fit.n > n
    # random subset
    sub.inx = sample.int(n, fit.n)
  }
  resids = resids[sub.inx, ]
  coords = coords[sub.inx, ]

  # cor
  cor.resids <- cor(t(resids))

  # calculate scaled distance
  D = dist.f(coords)
  max_d = max(D) # max distance among sub-samples

  # convert matrices to vectors and combine to data frame
  w = data.frame(dist =  D[upper.tri(D, diag = TRUE)],
                 cor = cor.resids[upper.tri(cor.resids, diag = TRUE)])

  # create formula from given function and match the named arguments in start
  nls.form <- as.formula(sprintf("cor ~ %s(dist, %s)", covar.f, toString(names(start))))

  # setup an error check boolean
  err.bool = FALSE
  # try fitting the nls, catching any errors
  err = tryCatch(expr = {fit <- nls(nls.form, data = w, start = start, ...)},
                 error = function(e){assign("err.bool", TRUE, pos = parent.frame(4));return(e)}
                 )

  # stop, if nls did not fit properly. Give some advice on what to do next.
  if (err.bool) {
    stop("nls failed to find a solution with the following error: ", "'", err$message, "'",
         "\n  Are values given by start on the same scale as distances calculated with distm_FUN?",
         "\n  If so, try different starting values or a different covar_FUN.",
         "\n  Simply re-running the funciton with different samples may also yield a solution.")
  }

  spcor = coef(fit)

  out <- list(call = call, mod = if(save_mod){fit}else{NULL}, spcor = spcor,
              max.distance = max_d, logLik = logLik(fit))
  class(out) <- append("remoteCor", class(out))
  return(out)
}

#' @title S3 print method for "remoteCor" class
#'
#' @param x remoteCor object to print
#' @param ... additional arguments passed to print()
#'
#' @return a print-formatted version of key elements of the "remoteCor" object.
print.remoteCor <- function(x, ...){
  # list(call = call, mod = fit, spcor = spcor, max.distance = max.d, logLik = logLik(fit))
  cat("\nCall:\n")
  print(x$call, ...)
  cat("\nSpatial parameter estimates:\n")
  print(x$spcor, ...)
  cat("\nMax distance:", x$max.distance,"\n")
  cat("\nLog-likelihood:\n")
  print(x$logLik, ...)
}

## test function ----
#' @title Test passing a covariance function and arguments
#'
#' @param d numeric vector or matrix of distances
#' @param covar_FUN distance-based covariance function to use,
#' which must take \code{d} as its first argument
#' @param covar.pars vector or list of parameters (other than d) passed to the
#' covar function
#'
test_covar_fun <- function(d, covar_FUN = "covar_exppow", covar.pars = list(range = .5)){
  cov_f <- match.fun(covar_FUN)
  # covar.pars$d = d
  if (is.null(covar.pars)){
    covar.pars = list(d)
  } else {
    covar.pars = as.list(append(list(d), covar.pars))
  }
  return(do.call(cov_f, covar.pars))
}
