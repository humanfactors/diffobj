# diffobj - Compare R Objects with a Diff
# Copyright (C) 2016  Brodie Gaslam
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# Go to <https://www.r-project.org/Licenses/GPL-3> for a copy of the license.

#' @include s4.R

NULL

#' Finalizing Methods
#'
#' Use as the \code{finalizer} slot to \code{\link{Style}} objects to wrap
#' character output prior to output to device.  Used primarily by styles that
#' output to HTML to properly configure HTML page structure.
#'
#' @export

setGeneric("finalizer", function(x, ...) standardGeneric("finalizer"))
setMethod("finalizer", c("ANY"),
  function(x, x.chr, style, js, ...) {
    if(!is.character(x.chr)) stop("Argument `x.chr` must be character")
    if(!is.chr.1L(js)) stop("Argument `js` must be character(1L) and not NA.")

    html.output <- style@html.output
    pager <- style@pager

    if(html.output == "auto") {
      html.output <- if(is(pager, "PagerBrowser")) "page" else "diff.only"
    }
    if(html.output %in% c("diff.w.style", "page")) {
      css.txt <- try(paste0(readLines(style@css), collapse="\n"))
      if(inherits(css.txt, "try-error")) stop("Cannot read css file ", css)
      css <- sprintf("<style type='text/css'>\n%s\n</style>", css.txt)
    }
    if(html.output == "diff.w.style") {
      tpl <- "%s%s"
    } else if (html.output == "page") {
      tpl <- sprintf("
        <!DOCTYPE html>
        <html>
          <head>
            %%s\n
          </head>
          <body>
            <div id='diffobj_outer'>\n%%s\n</div>
            <script type='text/javascript'>\n%s\n</script>
          </body>
        </html>",
        js
      )
    } else if (html.output == "diff.only") {
      css <- ""
      tpl <- "%s%s"
    } else stop("Logic Error: unexpected html.output; contact maintainer.")
    sprintf(tpl, css, paste0(x.chr, collapse=""))
  }
)