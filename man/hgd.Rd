% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/httpgd.R
\name{hgd}
\alias{hgd}
\title{Asynchronous HTTP server graphics device.}
\usage{
hgd(
  host = getOption("httpgd.host", "127.0.0.1"),
  port = getOption("httpgd.port", 0),
  cors = getOption("httpgd.cors", FALSE),
  token = getOption("httpgd.token", TRUE),
  silent = getOption("httpgd.silent", FALSE),
  width = getOption("httpgd.width", 720),
  height = getOption("httpgd.height", 576),
  zoom = getOption("httpgd.zoom", 1),
  bg = getOption("httpgd.bg", "white"),
  pointsize = getOption("httpgd.pointsize", 12),
  system_fonts = getOption("httpgd.system_fonts", list()),
  user_fonts = getOption("httpgd.user_fonts", list()),
  reset_par = getOption("httpgd.reset_par", FALSE)
)
}
\arguments{
\item{host}{Server hostname. Set to \code{"0.0.0.0"} to enable remote access.
We recommend to \strong{only enable remote access in trusted networks}.
The network security of httpgd has not yet been properly tested.}

\item{port}{Server port. If this is set to \code{0}, an open port
will be assigned.}

\item{cors}{Toggles Cross-Origin Resource Sharing (CORS) header.
When set to \code{TRUE}, CORS header will be set to \code{"*"}.}

\item{token}{(Optional) security token. When set, all requests
need to include a token to be allowed. (Either in a request header
(\code{X-HTTPGD-TOKEN}) field or as a query parameter.)
This parameter can be set to \code{TRUE} to generate a random 8 character
alphanumeric token. A random token of the specified length is generated
when it is set to a number. \code{FALSE} deactivates the token.}

\item{silent}{When set to \code{FALSE} no information will be printed to console.}

\item{width}{Initial plot width (pixels).}

\item{height}{Initial plot height (pixels).}

\item{zoom}{Initial plot zoom level (For example: 2 corresponds
to 200\%, 0.5 would be 50\%.).}

\item{bg}{Background color.}

\item{pointsize}{Graphics device point size.}

\item{system_fonts}{Named list of font names to be aliased with
fonts installed on your system. If unspecified, the R default
families \code{sans}, \code{serif}, \code{mono} and \code{symbol}
are aliased to the family returned by
\code{systemfonts::font_info()}.}

\item{user_fonts}{Named list of fonts to be aliased with font files
provided by the user rather than fonts properly installed on the
system. The aliases can be fonts from the fontquiver package,
strings containing a path to a font file, or a list containing
\code{name} and \code{file} elements with \code{name} indicating
the font alias in the SVG output and \code{file} the path to a
font file.}

\item{reset_par}{If set to \code{TRUE}, global graphics parameters will be saved
on device start and reset every time the plots are cleared (see
\code{\link[graphics:par]{graphics::par()}}).}
}
\value{
No return value, called to initialize graphics device.
}
\description{
This function initializes a httpgd graphics device and
starts a local webserver, that allows for access via HTTP and WebSockets.
A link will be printed by which the web client can be accessed using
a browser.
}
\details{
All font settings and descriptions are adopted from the excellent
'svglite' package.
}
\examples{
\dontrun{

hgd() # Initialize graphics device and start server
hgd_browse() # Or copy the displayed link in the browser

# Plot something
x <- seq(0, 3 * pi, by = 0.1)
plot(x, sin(x), type = "l")

dev.off() # alternatively: hgd_close()
}
}
