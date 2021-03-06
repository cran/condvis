#' @title Visualise a section in data space
#'
#' @description Visualise a section in data space, showing fitted models where
#'   they intersect the section, and nearby observations. The \code{weights} for
#'   observations can be calculated with \code{\link{similarityweight}}. This
#'   function is mainly for use in \code{\link{ceplot}} and
#'   \code{\link{condtour}}.
#'
#' @param xs A dataframe with one or two columns.
#' @param y A dataframe with one column.
#' @param xc.cond A dataframe with a single row, with all columns required for
#'   passing to \code{\link{predict}} methods of models in \code{model}.
#' @param model A fitted model object, or a list of such objects.
#' @param model.colour Colours for fitted models. If \code{model} is a list,
#'   this should be of same length as \code{model}.
#' @param model.lwd Line weight for fitted models. If \code{model} is a list,
#'   this should be of same length as \code{model}.
#' @param model.lty Line style for fitted models. If \code{model} is a list,
#'   this should be of same length as \code{model}.
#' @param model.name Character labels for models, for legend.
#' @param yhat Fitted values for the observations in \code{y}. Calculated if
#'   needed and not provided. Only used if showing residuals, or \code{xs} has
#'   two columns.
#' @param mar Margins for plot.
#' @param col Colours for observed data. Should be of length \code{nrow(xs)}.
#' @param weights Similarity weights for observed data. Should be of length
#'   \code{nrow(xs)}. Usually calculated with \code{\link{similarityweight}}.
#' @param view3d Logical; if \code{TRUE} plots a three-dimensional
#'   regression surface if possible.
#' @param theta3d,phi3d Angles defining the viewing direction. \code{theta3d}
#'   gives the azimuthal direction and \code{phi3d} the colatitude. See
#'   \code{\link[graphics]{persp}}.
#' @param xs.grid The grid of values defining the part of the section to
#'   visualise. Calculated if not provided.
#' @param prednew The \code{y} values where the models in \code{model} intersect
#'   the section. Useful when providing \code{theta3d}, \code{phi3d}, or
#'   \code{weights}, where the predict methods have been called elsewhere.
#' @param conf Logical; if \code{TRUE} plots confidence bounds (or equivalent)
#'   for models which provide this.
#' @param probs Logical; if \code{TRUE}, shows predicted class probabilities
#'   instead of just predicted classes. Only available if \code{xs} contains two
#'   numeric predictors and the model's predict method provides this.
#' @param pch Plot symbols for observed data
#' @param residuals Logical; if \code{TRUE}, plots a residual versus predictor
#'   plot instead of the usual scale of raw response.
#' @param main Character title for plot, default is
#'   \code{"Conditional expectation"}.
#' @param xlim Graphical parameter passed to plotting functions.
#' @param ylim Graphical parameter passed to plotting functions.
#'
#' @return A list containing relevant information for updating the plot.
#'
#' @examples
#' data(mtcars)
#' model <- lm(mpg ~ ., data = mtcars)
#' plotxs(xs = mtcars[, "wt", drop = FALSE], y = mtcars[, "mpg", drop = FALSE],
#'   xc.cond = mtcars[1, ], model = list(model))
#'
#' @seealso \code{\link{plotxc}}, \code{\link{ceplot}}, \code{\link{condtour}}
#'
#' @references O'Connell M, Hurley CB and Domijan K (2017). ``Conditional
#'   Visualization for Statistical Models: An Introduction to the
#'   \strong{condvis} Package in R.''\emph{Journal of Statistical Software},
#'   \strong{81}(5), pp. 1-20. <URL:http://dx.doi.org/10.18637/jss.v081.i05>.

plotxs <-
function (xs, y, xc.cond, model, model.colour = NULL, model.lwd = NULL,
  model.lty = NULL, model.name = NULL, yhat = NULL, mar = NULL, col = "black",
  weights = NULL, view3d = FALSE, theta3d = 45, phi3d = 20, xs.grid
  = NULL, prednew = NULL, conf = FALSE, probs = FALSE, pch = 1, residuals =
  FALSE, main = NULL, xlim = NULL, ylim = NULL)
{
  ny <- nrow(y)
  col <- rep(col, length.out = ny)
  main <- if (is.null(main))
    "Conditional expectation"
  else main
  dev.hold()

## If no weights are provided, just show all data with the appropriate colour.
## Otherwise, adjust the colours according to the weights, find the
## observations with weights greater than one, and order them for plotting.

  if (is.null(weights)){
    data.order <- 1:ny
    data.colour <- col
  } else {
    if (!identical(length(weights), ny))
      stop("'weights' should be same length as number of observations")
    data.colour <- weightcolor(col, weights)
    data.order <- attr(data.colour, "order")
  }

## Organise defaults and check inputs.

  pch <- rep(pch, length.out = ny)
  if (ncol(y) != 1)
    stop("y must be a dataframe with 1 column")
  model <- if (!is.list(model))
    list(model)
  else model
  model.colour <- if (is.null(model.colour)){
    if (requireNamespace("RColorBrewer", quietly = TRUE))
	    RColorBrewer::brewer.pal(n = max(length(model), 3L), name = "Dark2")
	  else rainbow(max(length(model), 4L))
  } else rep(model.colour, length.out = length(model))
  model.lwd <- if (is.null(model.lwd))
    rep(2, length(model))
  else rep(model.lwd, length.out = length(model))
  model.lty <- if (is.null(model.lty))
    rep(1, length(model))
  else rep(model.lty, length.out = length(model))
  model.name <- if (!is.null(names(model)))
    names(model)
  else paste("model", seq_along(model), sep = "_")
  mar <- if (is.null(mar))
    c(5, 4, 3, 2)
  else mar
  par(mar = mar)

## If xs is NULL, show a univariate summary

  if (is.null(xs) || identical(ncol(xs), 0L)){
    if (is.null(prednew)){
      newdata <- xc.cond
      prednew <- lapply(model, predict1, newdata = newdata, ylevels = if (
        nlevels(y[, 1L]) > 2) levels(y[, 1L]) else NULL)
    }
    fullhist <- hist(y[, 1L], border = NA)
    abline(v = unlist(prednew), col = model.colour, lwd = model.lwd, lty =
      model.lty)
    legend("topright", legend = model.name, col = model.colour, lwd =
      model.lwd, lty = model.lty)
    box()
    plot.type <- "residuals"
  } else {

## Otherwise, go through the various combinations of xs having one or two
## columns of factors or numerics, and y being factor or numeric.

## 'plot.type's are coded with 2 or 3 letters. The first one refers to the
## response, and the following letters refer to the predictors. For example,
## "cfc" refers to a continuous response, one factor predictor and one
## continuous predictor.

    if (identical(ncol(xs), 1L)){
      # xs has one column
      if (is.null(xs.grid)){
        if (!is.factor(xs[, 1L])){
          xs.min <- if (is.null(xlim))
            min(xs[, 1L], na.rm = TRUE)
          else xlim[1]
          xs.max <- if (is.null(xlim))
            max(xs[, 1L], na.rm = TRUE)
          else xlim[2]
          xs.grid <- data.frame(seq(xs.min, xs.max, length.out = if (view3d) 20L
            else 50L))
        } else {
          xs.grid <- data.frame(as.factor(levels(xs[, 1L])))
        }
        colnames(xs.grid) <- colnames(xs)
      }
      newdata <- makenewdata(xs = xs.grid, xc.cond = xc.cond)
      if (is.null(prednew))
	      prednew <- lapply(model, predict1, newdata = newdata, ylevels =
          if (nlevels(y[, 1L]) > 2) levels(y[, 1L]) else NULL)
      if (is.factor(xs[, 1L])){
        # xs is a factor
        if (is.factor(y[, 1L])){
          # y is factor
          plot.type <- "ff"
          if (identical(nlevels(y[, 1L]), 2L)){
            plot(unique(xs[, 1L]), rep(-888, length(levels(xs[, 1L]))), col =
              NULL, main = main, ylab = paste("Probability
              ", colnames(y)[1L], "=", levels(y[, 1L])[2L]), ylim = c(0, 1))
            if (length(data.order) > 0)
				      points.default((as.numeric(xs[data.order, 1L])) + rnorm(n =
                length(data.order), sd = 0.1), (as.integer(y[data.order, 1L]) -
                1) + rnorm(n = length(data.order), sd = 0.01), col =
                data.colour[data.order], pch = pch[data.order])
            for (i in seq_along(model)){
              if ("glm" %in% class(model[[i]])){
                points.default(xs.grid[, 1L], prednew[[i]], type = 'l', col =
                  model.colour[i], lwd = model.lwd[i], lty = model.lty[i])
              } else if (inherits(model[[i]], "gbm")){
                points.default(xs.grid[, 1L], prednew[[i]], type = 'l', col =
                  model.colour[i], lwd = model.lwd[i], lty = model.lty[i])
              } else {
                points.default(xs.grid[, 1L], as.numeric(prednew[[i]]) - 1, type
                  = 'l', col = model.colour[i], lwd = model.lwd[i], lty =
                  model.lty[i])
              }
            }
          } else {
            plot(range(as.numeric(xs[, 1L])) + c(0, 0.1 * abs(diff(range(
              as.numeric(xs[, 1L])))) ), range(as.integer(y[, 1L])), col = NULL,
              xlab = colnames(xs)[1L], ylab = colnames(y)[1L], yaxt = "n", main
              = main, xaxt = if (is.factor(xs[, 1L])) "n"
              else NULL)
            axis(2, at = 1:nlevels(y[, 1L]), labels = levels(y[, 1L]))
            if (is.factor(xs[, 1L]))
              axis(1, at = 1:nlevels(xs[, 1L]), labels = levels(xs[, 1L]))
            if (length(data.order) > 0)
              points(as.numeric(xs[data.order, 1L]), as.integer(y[data.order,
                1L]), col = data.colour[data.order], pch = pch[data.order])
            for (i in seq_along(model)){
              points.default(as.numeric(xs.grid[, 1L]), as.integer(prednew[[i]])
              , type = 'l', col = model.colour[i], lwd = model.lwd[i], lty =
              model.lty[i])
            }
          }
          legend("topright", legend = model.name, col = model.colour, lwd =
            model.lwd, lty = model.lty)
        } else {
          # y is continuous
          plot.type <- "cf"
          plot(unique(xs[, 1L]), rep(-888, length(levels(xs[, 1L]))), col = NULL
            , main = main, xlab = colnames(xs)[1L], ylab =
            colnames(y)[1L], ylim = if(is.null(ylim)) range(y[, 1L]) else ylim)
          if (length(data.order) > 0)
            points(xs[data.order, 1L], y[data.order, 1L], col = data.colour[
              data.order], pch = pch[data.order])
          if (conf){
            prednew2 <- lapply(model, confpred, newdata = newdata)
            for (i in seq_along(model)){
              points.default(xs.grid[, 1L], prednew[[i]], type = 'l', col =
                model.colour[i], lwd = model.lwd[i], lty = model.lty[i])
              if (all(c("lwr", "upr") %in% colnames(prednew2[[i]]))){
                points.default(xs.grid[, 1L], prednew2[[i]][, "lwr"], type = 'l'
                  , lty = 2, col = model.colour[i], lwd = max(0.8, 0.5 *
                  model.lwd[i]))
                points.default(xs.grid[, 1L], prednew2[[i]][, "upr"], type = 'l'
                  , lty = 2, col = model.colour[i], lwd = max(0.8, 0.5 *
                  model.lwd[i]))
              }
            }
          } else {
            for (i in seq_along(model)){
              points.default(xs.grid[, 1L], prednew[[i]], type = 'l', col =
                model.colour[i], lwd = model.lwd[i], lty =  model.lty[i])
            }
          }
          legend("topright", legend = model.name, col = model.colour, lwd =
            model.lwd, lty = model.lty)
        }
      } else {
        #xs is continuous
        if (is.factor(y[, 1L])){
          # y is factor
          plot.type <- "fc"
          if (identical(nlevels(y[, 1L]), 2L)){
            plot(range(xs[, 1L]) + 0.1 * abs(diff(range(xs[, 1L]))), c(0, 0),
              col = NULL, main = main, xlab = colnames(xs)[
              1L], ylab = paste("Probability ", colnames(y)[1L], "=", levels(y[,
              1L])[2L]), ylim = c(0, 1))
            if (length(data.order) > 0)
				      points.default(xs[data.order, 1L], as.integer(y[data.order, 1L]) -
                1, col = data.colour[data.order], pch = pch[data.order])
            for (i in seq_along(model)){
              if ("glm" %in% class(model[[i]])){
                points.default(xs.grid[, 1L], prednew[[i]], type = 'l', col =
                  model.colour[i], lwd = model.lwd[i], lty = model.lty[i])
              } else if (inherits(model[[i]], "gbm")){
                points.default(xs.grid[, 1L], prednew[[i]], type = 'l', col =
                  model.colour[i], lwd = model.lwd[i], lty = model.lty[i])
              } else {
                points.default(xs.grid[, 1L], as.numeric(prednew[[i]]) - 1, type
                  = 'l', col = model.colour[i], lwd = model.lwd[i], lty =
                  model.lty[i])
              }
            }
          } else {
            plot(range(xs[, 1L]), range(as.integer(y[, 1L])), col = NULL, xlab =
              colnames(xs)[1L], ylab = colnames(y)[1L], yaxt = "n", main =
              main, xaxt = if (is.factor(xs[, 1L])) "n"
              else NULL)
            axis(2, at = 1:nlevels(y[, 1L]), labels = levels(y[, 1L]))
            if (is.factor(xs[, 1L]))
              axis(1, at = 1:nlevels(xs[, 1L]), labels = levels(xs[, 1L]))
            if (length(data.order) > 0)
              points(xs[data.order, 1L], as.integer(y[data.order, 1L]), col =
                data.colour[data.order], pch = pch[data.order])
            for (i in seq_along(model)){
              points.default(as.numeric(xs.grid[, 1L]), as.integer(prednew[[i]])
                , type = 'l', col = model.colour[i], lwd = model.lwd[i], lty =
                model.lty[i])
            }
          }
          legend("topright", legend = model.name, col = model.colour, lwd =
            model.lwd, lty = model.lty)
        } else {
          # y is continuous
          plot.type <- "cc"
          plot(range(xs[, 1L]), range(y[, 1L]), col = NULL, main =
            main, xlab = colnames(xs)[1L], ylab = colnames(
            y)[1L], xlim = xlim, ylim = ylim)
          if (length(data.order) > 0){
            points(xs[data.order, 1L], y[data.order, 1L], col = data.colour[
              data.order], pch = pch[data.order])
          }
          if (conf){
            prednew2 <- lapply(model, confpred, newdata = newdata)
            for (i in seq_along(model)){
              points.default(xs.grid[, 1L], prednew[[i]], type = 'l', col =
                model.colour[i], lwd = model.lwd[i], lty = model.lty[i])
              if (all(c("lwr", "upr") %in% colnames(prednew2[[i]]))){
                points.default(xs.grid[, 1L], prednew2[[i]][, "lwr"], type = 'l'
                  , col = model.colour[i], lwd = max(0.8, 0.5 * model.lwd[i]),
                  lty = 2)
                points.default(xs.grid[, 1L], prednew2[[i]][, "upr"], type = 'l'
                  , col = model.colour[i], lwd = max(0.8, 0.5 * model.lwd[i]),
                  lty = 2)
              }
            }
          } else {
            for (i in seq_along(model)){
              points.default(xs.grid[, 1L], prednew[[i]], type = 'l', col =
                model.colour[i], lwd = model.lwd[i], lty = model.lty[i])
            }
          }
          pos <- if (cor(xs, y) < 0)
            "topright"
          else "bottomright"
          legend(pos, legend = model.name, col = model.colour, lwd = model.lwd,
            lty = model.lty)
        }
      }
    } else {
      # xs has two columns
      arefactorsxs <- vapply(xs, is.factor, logical(1L))
      if (is.null(xs.grid)){
        xs.grid1 <- if (!is.factor(xs[, 1L]))
          seq(min(xs[, 1L], na.rm = TRUE), max(xs[, 1L], na.rm = TRUE),
            length.out = if (view3d) {20L} else if (probs) 15 else 50L)
          else as.factor(levels(xs[, 1L]))
        xs.grid2 <- if (!is.factor(xs[, 2L]))
          seq(min(xs[, 2L], na.rm = TRUE), max(xs[, 2L], na.rm = TRUE),
            length.out = if (view3d) {20L} else if (probs) 15 else 50L)
          else as.factor(levels(xs[, 2L]))
        xs.grid <- data.frame(rep(xs.grid1, by = length(xs.grid2)), rep(xs.grid2
          , each = length(xs.grid1)))
        colnames(xs.grid) <- colnames(xs)
      }
      newdata <- makenewdata(xs = xs.grid, xc.cond = xc.cond)
      if (is.null(prednew))
        prednew <- lapply(model, predict1, newdata = newdata, ylevels = if (
          nlevels(y[, 1L]) > 2) levels(y[, 1L]) else NULL)
		  color <- if (is.factor(y[, 1L])){
        if (identical(nlevels(y[, 1L]), 2L) && inherits(model[[1L]], "glm")){
            factor2color(as.factor(round(prednew[[1L]])))
        } else factor2color(as.factor(prednew[[1L]]))
		  } else cont2color(prednew[[1L]], range(y[, 1L]))
      ybg <- if (length(data.order) > 0){
        if (is.factor(y[, 1L]))
		      factor2color(y[data.order, 1L])
		    else cont2color(y[data.order, 1L], range(y[, 1L]))
      } else NULL
      if (all(arefactorsxs)){
        # xs are both factors
			  xrect <- as.integer(xs.grid[, 1L])
			  yrect <- as.integer(xs.grid[, 2L])
		  	xoffset <- abs(diff(unique(xrect)[1:2])) / 2.1
			  yoffset <- abs(diff(unique(yrect)[1:2])) / 2.1
			  plot(xrect, yrect, col = NULL, xlab = colnames(xs)[1L], ylab = colnames(
          xs)[2L], xlim = c(min(xrect) - xoffset, max(xrect) + xoffset), xaxt =
          "n", bty = "n", ylim = c(min(yrect) - yoffset, max(yrect) + yoffset),
          yaxt = "n", main = main)
			  rect(xleft = xrect - xoffset, xright = xrect + xoffset, ybottom = yrect
          - yoffset, ytop = yrect + yoffset, col = color)
        if (length(data.order) > 0)
          points(jitter(as.integer(xs[data.order, 1L]), amount = 0.6 * xoffset),
            jitter(as.integer(xs[data.order, 2L]), amount = 0.6 * yoffset), bg =
            ybg, col = data.colour[data.order], pch = pch[data.order])
		    axis(1L, at = unique(xrect), labels = levels(xs[, 1L]), tick = FALSE)
			  axis(2L, at = unique(yrect), labels = levels(xs[, 2L]), tick = FALSE)
        if (is.factor(y[, 1L])){
          # y is factor
          plot.type <- "fff"
        } else {
          # y is continuous
          plot.type <- "cff"
        }
      } else {
        if (any(arefactorsxs)){
          # xs is one factor, one continuous
          plot.type <- if (is.factor(y[, 1L]))
            "ffc" # y is factor
          else "cfc" # y is continuous
    	    xrect <- xs.grid[, !arefactorsxs]
			    yrect <- as.integer(xs.grid[, arefactorsxs])
			    xoffset <- abs(diff(unique(xrect)[1:2])) / 2
			    yoffset <- abs(diff(unique(yrect)[1:2])) / 2.1
		      plot(0, 0, col = NULL, xlab = colnames(xs)[!arefactorsxs], ylab =
            colnames(xs)[arefactorsxs], xlim = c(min(xrect) - xoffset, max(xrect
            ) + xoffset), bty = "n", main = main, ylim =
            c(min(yrect) - yoffset, max(yrect) + yoffset), yaxt = "n")
		      rect(xleft = xrect - xoffset, xright = xrect + xoffset, ybottom =
            yrect - yoffset, ytop = yrect + yoffset, col = color, border = NA)
          if (length(data.order) > 0)
            points(jitter(xs[data.order, !arefactorsxs]), jitter(as.integer(xs[
              data.order, arefactorsxs])), bg = ybg, col = data.colour[
              data.order], pch = pch[data.order])
			    axis(2L, at = unique(yrect), labels = levels(xs[, arefactorsxs]),
            tick = FALSE)
        } else {
          # xs are both continuous
          if (is.factor(y[, 1L])){
            # y is factor
            plot.type <- "fcc"
            if (probs){
              plot(range(xs.grid[, 1L]), range(xs.grid[, 2L]), col = NULL, xlab
                = colnames(xs)[1L], ylab = colnames(xs)[2L], main =
                main)
              pred <- predict1(model[[1L]], newdata = newdata, probability =
                TRUE, ylevels = levels(y[, 1L]))
              p1 <- extractprobs(model[[1L]], pred)
              totalwidth <- abs(diff(par()$usr[1:2]))
              totalheight <- abs(diff(par()$usr[3:4]))
              o1 <- apply(cbind(xs.grid, p1), 1, function (x) myglyph2(
                x[1], x[2], 0.6 * totalwidth / 15, 0.6 * totalheight /
                15, x[3:(2 + ncol(p1))], factor2color(as.factor(levels(
                y[, 1L])))))
              o2 <- matrix(t(o1), ncol = 5, byrow = FALSE)
              rect(xleft = o2[, 1], xright = o2[, 2], ybottom = o2[, 3],
                ytop = o2[, 4], col = factor2color(as.factor(levels(
                y[, 1L])))[o2[, 5]])
            } else {
              xoffset <- abs(diff(unique(xs.grid[, 1L])[1:2])) / 2
              yoffset <- abs(diff(unique(xs.grid[, 2L])[1:2])) / 2
              plot(range(xs.grid[, 1L]), range(xs.grid[, 2L]), col = NULL,
                xlab = colnames(xs)[1L], ylab = colnames(xs)[2L],
                main = main)
              rect(xleft = xs.grid[, 1L] - xoffset, xright = xs.grid[, 1L]
                + xoffset, ybottom = xs.grid[, 2L] - yoffset, ytop =
                xs.grid[, 2L] + yoffset, col = color, border = NA)
              if (length(data.order) > 0)
                points(xs[data.order, , drop = FALSE], bg = ybg, col =
                  data.colour[data.order], pch = pch[data.order])
            }
          } else {
            # y is continuous
            plot.type <- "ccc"
            if (view3d){
              yhat <- if (is.null(yhat))
                lapply(model[1], predict1, ylevels = NULL)
              else yhat
              z <- matrix(prednew[[1L]], ncol = 20L, byrow = FALSE)
              zfacet <- (z[-1, -1] + z[-1, -ncol(z)] + z[-nrow(z), -1]
                + z[-nrow(z), -ncol(z)]) / 4
              colorfacet <- cont2color(zfacet, range(y[, 1L]))
              par(mar = c(3, 3, 3, 3))
              persp.object <- suppressWarnings(persp(x = unique(xs.grid[, 1L])
                , y = unique(xs.grid[, 2L]), border = rgb(0.3, 0.3, 0.3), lwd
                = 0.1, z = z, col = colorfacet, zlim = range(y), xlab =
                colnames(xs)[1L], ylab = colnames(xs)[2L], zlab = colnames(y)[
                1L], d = 10, ticktype = "detailed", main =
                main, theta = theta3d, phi = phi3d))
              if (length(data.order) > 0){
                points(trans3d(xs[data.order, 1L], xs[data.order, 2L], y[
                  data.order, 1L], pmat = persp.object), col = data.colour[
                  data.order], pch = pch[data.order])
                linestarts <- trans3d(xs[data.order, 1L], xs[data.order, 2L],
                  y[data.order, 1L], pmat = persp.object)
                lineends <- trans3d(xs[data.order, 1L], xs[data.order, 2L],
                  yhat[[1]][data.order], pmat = persp.object)
                segments(x0 = linestarts$x, y0 = linestarts$y, x1 = lineends$x
                  , y1 = lineends$y, col = data.colour[data.order])
              }
            } else {
              xoffset <- abs(diff(unique(xs.grid[, 1L])[1:2])) / 2
              yoffset <- abs(diff(unique(xs.grid[, 2L])[1:2])) / 2
              plot(range(xs.grid[, 1L]), range(xs.grid[, 2L]), col = NULL,
                xlab = colnames(xs)[1L], ylab = colnames(xs)[2L], main =
                main)
              rect(xleft = xs.grid[, 1L] - xoffset, xright = xs.grid[, 1L] +
                xoffset, ybottom = xs.grid[, 2L] - yoffset, ytop = xs.grid[,
                2L] + yoffset, col = color, border = NA)
              if (length(data.order) > 0)
                points(xs[data.order, , drop = FALSE], bg = ybg, col =
                  data.colour[data.order], pch = pch[data.order])
            }
          }
        }
      }
    }
  }
  dev.flush()
  invisible(structure(list(xs = xs, y = y, xc.cond = xc.cond, model = model,
    model.colour = model.colour, model.lwd = model.lwd, model.lty = model.lty,
    model.name = model.name, yhat = yhat, mar = par("mar"), data.colour =
    data.colour, data.order = data.order, view3d = view3d, theta3d = theta3d,
    usr = par("usr"), phi3d = phi3d, plot.type = if (exists("plot.type"))
    plot.type else NULL, screen = screen(), device = dev.cur(), xs.grid =
    xs.grid, newdata = newdata, prednew = prednew, xs.grid = xs.grid, conf =
    conf, probs = probs, pch = pch, col = col, ny = ny), class = "xsplot"))
}

## Helper function to produce a legend to go with plotxs

xslegend <-
function (y, name = NULL)
{
  if (is.factor(y)){
	  par(mar = c(0, 0, 0, 0))
    legend("left", legend = levels(y), fill = factor2color(as.factor(levels(y)))
      , title = if (!is.null(name)) name else "", bg = "white")
	} else {
		par(mar = c(8, 2.2, 8, 2.2))
    fullrange <- abs(diff(range(y)))
		yrange <- seq(min(y, na.rm = TRUE) - 0.15 * fullrange, max(y, na.rm = TRUE)
      + 0.15 * fullrange, length.out = 80L)
		spacing <- abs(diff(unique(yrange[1:2]))) / 2
    plot(0, 0, xaxt = "n", main = if (!is.null(name)) name else "", ylab = "",
      col = NULL, pch = 16, xlab = "", bty = "n", xlim = c(-0.5, 0.5), ylim =
      range(y))
    rect(xleft = -0.7, xright = 0.7, ybottom = yrange - spacing, ytop = yrange +
      spacing, col = cont2color(yrange, range(y)), border = NA)
		box()
	}
}
