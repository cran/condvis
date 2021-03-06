% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/makepath.R
\name{makepath}
\alias{makepath}
\title{Make a default path for conditional tour}
\usage{
makepath(x, ncentroids, ninterp = 4)
}
\arguments{
\item{x}{A dataframe}

\item{ncentroids}{The number of centroids to use as path nodes.}

\item{ninterp}{The number of points to linearly interpolate between path
nodes.}
}
\value{
A list with two dataframes: \code{centers} giving the path nodes, and
  \code{path} giving the full interpolated path.
}
\description{
Provides a default path (a set of sections), useful as input to
  a conditional tour (\code{\link{condtour}}). Clusters the data using
  k-means or partitioning around medoids (from the \code{cluster} package).
  The cluster centres/prototypes are then ordered to create a sensible way to
  visit each section as smoothly as possible. Ordering uses either the
  \code{DendSer} or \code{TSP} package. Linear interpolation is then used to
  create intermediate points between the path nodes.
}
\examples{
d <- data.frame(x = runif(500), y = runif(500))
plot(d)
mp1 <- makepath(d, 5)
points(mp1$centers, type = "b", col = "blue", pch = 16)
mp2 <- makepath(d, 40)
points(mp2$centers, type = "b", col = "red", pch = 16)

}
\seealso{
\code{\link{condtour}}
}

