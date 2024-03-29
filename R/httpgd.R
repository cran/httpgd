
#' Asynchronous HTTP server graphics device.
#'
#' This function initializes a httpgd graphics device and
#' starts a local webserver, that allows for access via HTTP and WebSockets.
#' A link will be printed by which the web client can be accessed using
#' a browser.
#'
#' All font settings and descriptions are adopted from the excellent
#' 'svglite' package.
#'
#' @param host Server hostname. Set to `"0.0.0.0"` to enable remote access.
#'   We recommend to **only enable remote access in trusted networks**.
#'   The network security of httpgd has not yet been properly tested.
#' @param port Server port. If this is set to `0`, an open port
#'   will be assigned.
#' @param width Initial plot width (pixels).
#' @param height Initial plot height (pixels).
#' @param zoom Initial plot zoom level (For example: 2 corresponds
#'   to 200%, 0.5 would be 50%.).
#' @param bg Background color.
#' @param pointsize Graphics device point size.
#' @param system_fonts Named list of font names to be aliased with
#'   fonts installed on your system. If unspecified, the R default
#'   families `sans`, `serif`, `mono` and `symbol`
#'   are aliased to the family returned by
#'   `systemfonts::font_info()`.
#' @param user_fonts Named list of fonts to be aliased with font files
#'   provided by the user rather than fonts properly installed on the
#'   system. The aliases can be fonts from the fontquiver package,
#'   strings containing a path to a font file, or a list containing
#'   `name` and `file` elements with `name` indicating
#'   the font alias in the SVG output and `file` the path to a
#'   font file.
#' @param cors Toggles Cross-Origin Resource Sharing (CORS) header.
#'   When set to `TRUE`, CORS header will be set to `"*"`.
#' @param token (Optional) security token. When set, all requests
#'   need to include a token to be allowed. (Either in a request header
#'   (`X-HTTPGD-TOKEN`) field or as a query parameter.)
#'   This parameter can be set to `TRUE` to generate a random 8 character
#'   alphanumeric token. A random token of the specified length is generated
#'   when it is set to a number. `FALSE` deactivates the token.
#' @param silent When set to `FALSE` no information will be printed to console.
#' @param reset_par If set to `TRUE`, global graphics parameters will be saved
#'   on device start and reset every time the plots are cleared (see
#'   [graphics::par()]).
#'
#' @return No return value, called to initialize graphics device.
#'
#' @importFrom unigd ugd
#' @export
#'
#' @examples
#' \dontrun{
#'
#' hgd() # Initialize graphics device and start server
#' hgd_browse() # Or copy the displayed link in the browser
#'
#' # Plot something
#' x <- seq(0, 3 * pi, by = 0.1)
#' plot(x, sin(x), type = "l")
#'
#' dev.off() # alternatively: hgd_close()
#' }
hgd <-
  function(host = getOption("httpgd.host", "127.0.0.1"),
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
           reset_par = getOption("httpgd.reset_par", FALSE)) {
    udev <- ugd(
      width / zoom,
      height / zoom,
      bg,
      pointsize,
      system_fonts,
      user_fonts,
      reset_par
    )

    if (!hgd_attach(
      which = udev,
      host = host,
      port = port,
      cors = cors,
      token = token,
      silent = silent
    )) {
      dev.off(which = udev)
      stop("Failed to start server. (Port might be in use.)")
    }
  }

hgd_attach <- function(which = dev.cur(),
                       host = getOption("httpgd.host", "127.0.0.1"),
                       port = getOption("httpgd.port", 0),
                       cors = getOption("httpgd.cors", FALSE),
                       token = getOption("httpgd.token", TRUE),
                       silent = getOption("httpgd.silent", FALSE)) {
  tok <- if (is.character(token)) {
    token
  } else if (is.numeric(token)) {
    httpgd_random_token_(token)
  } else if (is.logical(token) && token) {
    httpgd_random_token_(8)
  } else {
    ""
  }

  attached <- httpgd_(
    which,
    host,
    port,
    cors,
    tok,
    silent,
    wwwpath = system.file("www", package = "httpgd")
  )

  if (attached && !silent) {
    hgd_print_welcome(which)
  }

  return(attached)
}

hgd_print_welcome <- function(which) {
  cat("httpgd server running at:\n")
  hgdinfo <- hgd_details(which)
  if (hgdinfo$host == "0.0.0.0") {
    cat(sprintf("  %s\n", hgd_url(which = which, host = "127.0.0.1")))
  }
  cat(sprintf("  %s\n", hgd_url(which = which)))
}

#' httpgd device status.
#'
#' Access status information of a httpgd graphics device.
#' This function will only work after starting a device with [hgd()].
#'
#' @param which Which device (ID).
#'
#' @return List of status variables with the following named items:
#'   `$host`: Server hostname,
#'   `$port`: Server port,
#'   `$token`: Security token,
#'   `$hsize`: Plot history size (how many plots are accessible),
#'   `$upid`: Update ID (changes when the device has received new information),
#'   `$active`: Is the device the currently activated device.
#'
#' @importFrom grDevices dev.cur
#' @importFrom unigd ugd_state
#' @export
#'
#' @examples
#' \dontrun{
#'
#' hgd()
#' hgd_details()
#' plot(1, 1)
#' hgd_details()
#'
#' dev.off()
#' }
hgd_details <- function(which = dev.cur()) {
  httpgd_details_(which)
}


build_http_query <- function(x) {
  a <- unlist(lapply(x, function(p) {
    utils::URLencode(paste(p), reserved = TRUE)
  }))
  paste(names(a), a, sep = "=", collapse = "&")
}

#' httpgd URL.
#'
#' Generate URLs to the plot viewer or to plot SVGs.
#' This function will only work after starting a device with [hgd()].
#'
#' Note: If the included client is used set `websockets=0` or
#' `sidebar=0` to turn off WebSocket or plot history sidebar.
#'
#' @param endpoint API endpoint. The default, `"live"` is the HTML/JS
#'   plot viewer. Can be set to a numeric plot index or plot ID
#'   (see [unigd::ugd_id()]) to obtain the direct URL to the SVG.
#' @param which Which device (ID).
#' @param host Replaces hostname.
#' @param port Replaces port.
#' @param explicit Ads `hgd={host}:{port}` query parameter. Needed for host
#'   resolution in some editors.
#' @param omit_token Should the security token be omitted from the URL.
#' @param \\dots Other query parameters that will be appended to the URL.
#'
#' @return URL.
#'
#' @importFrom grDevices dev.cur
#' @export
#'
#' @examples
#' \dontrun{
#'
#' hgd()
#' my_url <- hgd_url()
#' hgd_url(0)
#' hgd_url(plot_id(), width = 800, height = 600)
#'
#' dev.off()
#' }
hgd_url <- function(endpoint = "live",
                    which = dev.cur(),
                    host = NA,
                    port = NA,
                    explicit = FALSE,
                    omit_token = FALSE,
                    ...) {
  det <- hgd_details(which)
  qry <- list(...)

  if (!is.na(host)) {
    det$host <- host
  } else if (det$host == "0.0.0.0") {
    det$host <- Sys.info()[["nodename"]]
  }
  if (!is.na(port)) {
    det$port <- paste(port)
  }

  if (!omit_token && (nchar(det$token) > 0)) {
    qry["token"] <- det$token
  }

  sprintf(
    "http://%s:%s/%s%s",
    det$host,
    det$port,
    endpoint,
    ifelse(length(qry) == 0, "", paste0("?", build_http_query(qry)))
  )
}

#' Open httpgd URL in the browser.
#'
#' This function will only work after starting a device with [hgd()].
#'
#' @param ... Parameters passed to [hgd_url()].
#' @param which Which device (ID).
#' @param browser Program to be used as HTML browser.
#'
#' @return URL.
#'
#' @importFrom grDevices dev.cur
#' @importFrom utils browseURL
#' @export
#'
#' @examples
#' \dontrun{
#'
#' hgd()
#' hgd_browse() # open browser
#' hist(rnorm(100))
#'
#' dev.off()
#' }
hgd_browse <- function(..., which = dev.cur(), browser = getOption("browser")) {
  browseURL(url = hgd_url(..., which = which), browser = browser)
}

#' Open httpgd URL in the IDE.
#'
#' Global option `viewer` needs to be set to a function that accepts the client
#' URL as a parameter.
#'
#' This function will only work after starting a device with [hgd()].
#'
#' @return `viewer` function return value.
#'
#' @export
#'
#' @examples
#' \dontrun{
#'
#' hgd()
#' hgd_view()
#' hist(rnorm(100))
#'
#' dev.off()
#' }
hgd_view <- function() {
  v <- getOption("viewer")
  if (is.null(v)) {
    stop(
      "'viewer' option not set. ",
      "(Open a viewer in the system browser instead by calling: `hgd_browse()`)"
    )
  }
  v(hgd_url(explicit = T))
}

#' Close httpgd device.
#'
#' This achieves the same effect as [grDevices::dev.off()],
#' but will only close the device if it has the httpgd type.
#'
#' @param which Which device (ID).
#' @param all Should all running httpgd devices be closed.
#'
#' @return Number and name of the new active device (after the specified device
#'   has been shut down).
#'
#' @importFrom grDevices dev.cur
#' @importFrom unigd ugd_close
#' @export
#'
#' @examples
#' \dontrun{
#'
#' hgd()
#' hgd_browse() # open browser
#' hist(rnorm(100))
#' hgd_close() # Equvalent to dev.off()
#'
#' hgd()
#' hgd()
#' hgd()
#' hgd_close(all = TRUE)
#' }
hgd_close <- function(which = dev.cur(), all = FALSE) {
  ugd_close(which, all) # todo: only close httpgd client devices?
}

#' Generate random alphanumeric token.
#'
#' This is mainly used internally by httpgd, but exposed for
#' testing purposes.
#'
#' @param len Token length (number of characters).
#'
#' @return Random token string.
#' @export
#'
#' @examples
#' hgd_generate_token(6)
hgd_generate_token <- function(len) {
  httpgd_random_token_(len)
}

files_snapshot <- function(files) {
  data.frame(file = files, mtime = file.info(files)[, "mtime"])
}

files_changed <- function(snap1, snap2) {
  snap1$file[snap1$mtime != snap2$mtime]
}

#' Watch for changes in code files and refresh plots automatically.
#'
#' This function may be used to rapidly develop visualizations
#' by replacing a workflow of reloading and executing code manually.
#'
#' @param watch Paths that are watched for changes (see [utils::fileSnapshot()])
#' @param on_change Will be called when a file changes.
#' @param interval Time interval in which changes are detected (in seconds).
#' @param on_start Will be called after the httpgd server is started
#'   (may be set to `NULL`).
#' @param on_exit Will be called before the server is closed
#'   (may be set to `NULL`).
#' @param on_error Will be called when on_change throws an error
#'   (may be set to `NULL`).
#' @param reset_par If set to `TRUE`, global graphics parameters will be saved
#'   on device start and reset every time [unigd::ugd_clear()] is called (see
#'   [graphics::par()]).
#' @param ... Additional parameters passed to `hgd(webserver=FALSE, ...)`
#'
#' @importFrom utils changedFiles fileSnapshot
#' @importFrom unigd ugd_clear
#' @export
#'
#' @examples
#' \dontrun{
#'
#' # --- my_code.R ---
#'
#' plot(rnorm(100), col = "red")
#'
#' # --- Other file / interactive ---
#'
#' hgd_watch(
#'   watch = "my_code.R", # When my_code.R changes...
#'   on_change = function(...) {
#'     source("my_code.R") # ...call updated plot function.
#'   }
#' )
#' }
hgd_watch <- function(watch = list.files(pattern = "\\.R$", ignore.case = T),
                      on_change = function(changed_files) {
                        print(changed_files)
                      },
                      interval = 1,
                      on_start = hgd_browse,
                      on_exit = NULL,
                      on_error = print,
                      reset_par = TRUE,
                      ...) {
  if (is.null(on_error)) {
    on_error <- function(...) {}
  }

  hgd(..., reset_par = reset_par) # todo move this to unigd, inject client
  tryCatch(
    {
      if (!is.null(on_start)) {
        on_start()
      }
      files_previous <- files_snapshot(watch)
      tryCatch(
        {
          on_change(c())
        },
        error = on_error
      )
      while (TRUE) {
        files_current <- files_snapshot(watch)
        changes <- files_changed(files_previous, files_current)
        if (length(changes) > 0) {
          ugd_clear()
          files_previous <- files_current
          tryCatch(
            {
              on_change(changes)
            },
            error = on_error
          )
        }
        Sys.sleep(interval)
      }
    },
    finally = {
      if (!is.null(on_exit)) {
        tryCatch(
          {
            on_exit()
          },
          finally = {
            dev.off()
          }
        )
      } else {
        dev.off()
      }
    }
  )
}
