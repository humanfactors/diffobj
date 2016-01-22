#' Run Text Diffs on R Objects
#'
#' Implements tools similar to \code{\link{tools::Rdiff}} that operate directly
#' on R objects instead of R terminal output stored in \code{.out} files.  The
#' difference computations are based on the Myers algorithm with the linear
#' space modification as implemented by Mike B. Allen in \code{libmba-0.9.1}.
#' This is the same algorithm used by default by the GNU diff UNIX utility.
#'
#' @name diffr-package
#' @docType package

NULL

setClassUnion("charOrNULL", c("character", "NULL"))

#' Dummy Doc File for S4 Methods with Existing Generics
#'
#' @keywords internal
#' @name diffr_s4method_doc
#' @rdname diffr_s4method_doc

NULL

# Classes for tracking intermediate diff obj data
#
# DiffDiffs contains a slot corresponding to each of target and current where
# a TRUE value means the corresponding value matches in both objects and FALSE
# means that it does not match

setClass(
  "diffrDiffDiffs",
  slots=c(target="integer", current="integer", white.space="logical"),
  validity=function(object) {
    if(!is.TF(object@white.space))
      return("slot `white.space` must be TRUE or FALSE")
    TRUE
  }
)
setClass(
  "diffrDiff",
  slots=c(
    tar.capt="character",
    cur.capt="character",
    tar.exp="ANY",
    cur.exp="ANY",
    mode="character",
    diffs="diffrDiffDiffs",
    tar.capt.def="charOrNULL",
    cur.capt.def="charOrNULL"
  ),
  prototype=list(mode="print"),
  validity=function(object) {
    if(!is.chr1(object@mode) || ! object@mode %in% c("print", "str"))
      return("slot `mode` must be either \"print\" or \"str\"")
    if(length(object@tar.capt) != length(object@diffs@target))
      return("slot `tar.capt` must be same length as slot `diffs@target`")
    if(length(object@cur.capt) != length(object@diffs@current))
      return("slot `cur.capt` must be same length as slot `diffs@current`")
    TRUE
} )
#' @rdname diffr_s4method_doc

setMethod("any", "diffrDiff",
  function(x, ..., na.rm = FALSE) {
    dots <- list(...)
    if(length(dots))
      stop("`any` method for `diffrDiff` supports only one argument")
    any(tarDiff(x), curDiff(x))
} )
setMethod("any", "diffrDiffDiffs",
  function(x, ..., na.rm = FALSE) {
    dots <- list(...)
    if(length(dots))
      stop("`any` method for `diffrDiff` supports only one argument")
    any(tarDiff(x), curDiff(x))
} )

#' @rdname diffr_s4method_doc

setMethod("as.character", "diffrDiff",
  function(x, context, width, ...) {
    context <- check_context(context)
    width <- check_width(width)
    white.space <- x@diffs@white.space

    len.max <- max(length(x@tar.capt), length(x@cur.capt))
    if(!any(x)) {
      msg <- "No visible differences between objects"
      if(!x@diffs@white.space) {
        xa <- char_diff(x@tar.capt, x@cur.capt, white.space=TRUE)
        if(any(xa))
          msg <- cc(
            "Only visible differences between objects are horizontal white ",
            "spaces. You can re-run diff with `white.space=TRUE` to show them."
          )
      }
      return(clr(word_wrap(msg, width=width), "silver"))
    }
    show.range <- diff_range(x, context)
    show.range.tar <- intersect(show.range, seq_along(x@tar.capt))
    show.range.cur <- intersect(show.range, seq_along(x@cur.capt))

    # Detect whether we should attempt to deal with wrapping objects, if so
    # overwrite cur/tar.body/rest variables with the color diffed wrap word
    # diffs; note that if the tar/cur.capt.def is not NULL then the objects
    # being compared must be atomic vectors

    cur.body <- tar.body <- character(0L)
    cur.rest <- show.range.cur
    tar.rest <- show.range.tar

    if(
      identical(x@mode, "print") && identical(x@tar.capt, x@tar.capt.def) &&
      identical(x@cur.capt, x@cur.capt.def)
    ) {
      # Separate out the stuff that can wrap (starts with index headers vs. not)

      cur.head.raw <- find_brackets(x@cur.capt)
      tar.head.raw <- find_brackets(x@tar.capt)

      cur.head <- cur.head.raw[cur.head.raw %in% show.range]
      tar.head <- tar.head.raw[tar.head.raw %in% show.range]

      if(length(cur.head) && length(tar.head)) {
        # note we modify `x` here so that subsequent steps can re-use `x` with
        # modifications

        pat <- sprintf("%s\\K.*", .brack.pat)
        cur.body <- regexpr(pat, x@cur.capt[cur.head], perl=TRUE)
        tar.body <- regexpr(pat, x@tar.capt[tar.head], perl=TRUE)

        body.diff <- diff_word(
          regmatches(x@tar.capt[tar.head], tar.body),
          regmatches(x@cur.capt[cur.head], cur.body),
          across.lines=TRUE, white.space=white.space
        )
        regmatches(x@tar.capt[tar.head], tar.body) <- body.diff$target
        regmatches(x@cur.capt[cur.head], cur.body) <- body.diff$current

        # We also need to diff the row headers

        cur.r.h <- regexpr(.brack.pat, x@cur.capt[cur.head], perl=TRUE)
        tar.r.h <- regexpr(.brack.pat, x@tar.capt[tar.head], perl=TRUE)

        cur.r.h.txt <- regmatches(x@cur.capt[cur.head], cur.r.h)
        tar.r.h.txt <- regmatches(x@tar.capt[tar.head], tar.r.h)

        x.r.h <- new(
          "diffrDiff", tar.capt=tar.r.h.txt, cur.capt=cur.r.h.txt,
          diffs=char_diff(tar.r.h.txt, cur.r.h.txt, white.space=white.space)
        )
        r.h.diff <- diff_line(x.r.h)
        regmatches(x@tar.capt[tar.head], tar.r.h) <- r.h.diff$target
        regmatches(x@cur.capt[cur.head], cur.r.h) <- r.h.diff$current

        # Everything else gets a normal line diff

        cur.rest <- show.range.cur[!show.range.cur %in% cur.head]
        tar.rest <- show.range.tar[!show.range.tar %in% tar.head]
      }
    }
    # Do the line diffs

    diff.fin <- diff_line(x, tar.rest, cur.rest)

    # Add all the display stuff

    c(
      obj_screen_chr(
        diff.fin$target,  x@tar.exp, diffs=tarDiff(x), range=show.range,
        width=width, pad= "-  ", color="red"
      ),
      obj_screen_chr(
        diff.fin$current,  x@cur.exp, diffs=curDiff(x), range=show.range,
        width=width, pad= "+  ", color="green"
    ) )
} )
setGeneric("tarDiff", function(x, ...) standardGeneric("tarDiff"))
setMethod("tarDiff", "diffrDiff", function(x, ...) tarDiff(x@diffs))
setGeneric("curDiff", function(x, ...) standardGeneric("curDiff"))
setMethod("curDiff", "diffrDiff", function(x, ...) curDiff(x@diffs))
setMethod("tarDiff", "diffrDiffDiffs", function(x, ...) {
  is.na(x@target) | !!x@target
} )
setMethod("curDiff", "diffrDiffDiffs", function(x, ...) {
  is.na(x@current) | !!x@current
} )
diff_rdiff <- function(target, current) {
  stopifnot(is.character(target), is.character(current))
  a <- tempfile("diffrRdiffa")
  writeLines(target, a)
  b <- tempfile("diffrRdiffb")
  writeLines(current, b)
  diff <- capture.output(system(paste("diff -bw", shQuote(a), shQuote(b))))
}
# If there is an error, we want to show as much of the objects as we can
# centered on the error.  If we can show the entire objects without centering
# then we do that.
#
# Returns the range of values that should be shown on both objects.  Note that
# this can include out of range indices if one object is larger than the other

diff_range <- function(x, context) {
  stopifnot(is(x, "diffrDiff"))
  context <- check_context(context)
  len.max <- max(length(x@tar.capt), length(x@cur.capt))
  first.diff <- if(!any(x)) 1L else min(which(tarDiff(x)), which(curDiff(x)))

  show.range <- if(len.max <= 2 * context[[1L]] + 1) {
    1:len.max
  } else {
    rng.trim <- 2 * context[[2L]] + 1
    if(first.diff <= rng.trim) {
      # if can show first diff starting from beginning, do that
      1:rng.trim
    } else if (len.max - first.diff + 1 <= rng.trim) {
      # if first diff is close to end, then show through end
      tail(1:len.max, rng.trim)
    } else {
      # if first diff is too close to beginning or end, use extra context on
      # other side of error

      end.extra <- max(0, context[[2L]] - first.diff)
      start.extra <- max(0, context[[2L]] - (len.max - first.diff))
      seq(
        max(first.diff - context[[2L]] - start.extra, 1),
        min(first.diff + context[[2L]] + end.extra, len.max)
      )
    }
  }
  show.range
}

# Matches up mismatched lines and word diffs them line by line, lines that
# cannot be matched up are fully diffed
#
# Designed to operate on subsets of an original diff, hence tar.range and
# cur.range

diff_line <- function(
  x, tar.range=seq_along(tarDiff(x)), cur.range=seq_along(curDiff(x))
) {
  # Run line diffs on the remaining lines
  # Match up the diffs; first step is to do word diffs on the matched
  # mismatches. Start by getting the match ids that are not NA and
  # greater than zero

  white.space <- x@diffs@white.space
  tar.diff <- x@diffs@target[tar.range]
  cur.diff <- x@diffs@current[cur.range]

  match.ids <- Filter(identity, tar.diff)

  # Now find the indeces of these ids that are in display range

  tar.ids.mismatch <- match(match.ids, x@diffs@target[tar.range])
  cur.ids.mismatch <- match(match.ids, x@diffs@current[cur.range])
  if( any(is.na(c(tar.ids.mismatch, cur.ids.mismatch))))
    stop("Logic Error: mismatched mismatches; contact maintainer.")

  # Add word colors

  tar.txt <- x@tar.capt[tar.range]
  cur.txt <- x@cur.capt[cur.range]

  word.color <-
    diff_word(
      tar.txt[tar.ids.mismatch], cur.txt[cur.ids.mismatch],
      white.space=white.space
    )

  tar.txt[tar.ids.mismatch] <- word.color$target
  cur.txt[cur.ids.mismatch] <- word.color$current

  # Color lines that were not word colored

  tar.seq <- seq_along(tar.txt)
  cur.seq <- seq_along(cur.txt)
  tar.line.diff <- setdiff(which(tarDiff(x)[tar.range]), tar.ids.mismatch)
  cur.line.diff <- setdiff(which(curDiff(x)[cur.range]), cur.ids.mismatch)

  tar.txt[tar.line.diff] <- clr(tar.txt[tar.line.diff], color="red")
  cur.txt[cur.line.diff] <- clr(cur.txt[cur.line.diff], color="green")

  # Re-sub back into the entire character vector

  x@tar.capt[tar.range] <- tar.txt
  x@cur.capt[cur.range] <- cur.txt

  # return

  list(target=x@tar.capt, current=x@cur.capt)
}

# groups characters based on whether they are different or not and colors
# them; assumes that the chrs vector values are words that were previously
# separated by spaces, and collapses the strings back with the spaces at the
# end

color_words <- function(chrs, diffs, color) {
  stopifnot(length(chrs) == length(diffs))
  if(length(chrs)) {
    grps <- cumsum(c(0, abs(diff(diffs))))
    chrs.grp <- tapply(chrs, grps, paste0, collapse=" ")
    diff.grp <- tapply(diffs, grps, head, 1L)
    cc(diff_color(chrs.grp, diff.grp, seq_along(chrs.grp), color), c=" ")
  } else cc(chrs)
}
# Try to use fancier word matching with vectors and matrices

.brack.pat <- "^ *\\[\\d+\\]"

# Determine if a string contains what appear to be standard index headers
#
# Returns index of elements in string that start with index headers.
# Note that it is permissible to have ouput that doesn't match brackets
# provided that it starts with brackets (e.g. attributes shown after break
# pattern)

find_brackets <- function(x) {
  stopifnot(is.character(x), all(!is.na(x)))
  matches <- regexpr(.brack.pat,  x)
  vals <- regmatches(x, matches)
  # the matching section must be uninterrupted starting from first line
  # and must have consisten formatting

  brackets <- which(cumsum(!nzchar(vals)) == 0L)
  vals.in.brk <- vals[brackets]
  nums.in.brk <- regmatches(vals.in.brk, regexpr("\\d+", vals.in.brk))

  if(
    length(brackets) && length(unique(nchar(vals.in.brk)) == 1L) &&
    length(unique(diff(as.integer(nums.in.brk)))) <= 1L
  ) {
    brackets
  } else integer(0L)
}
# Apply diff algorithm within lines
#
# For each line, splits into words, runs diffs, and colors them appropriately.
# For `across.lines=TRUE`, merges all lines into one and does the word diff on
# a single line to allow for the diff to look for matches across lines, though
# the result is then unwrapped back to the original lines.

diff_word <- function(target, current, across.lines=FALSE, white.space) {
  stopifnot(
    is.character(target), is.character(current),
    all(!is.na(target)), all(!is.na(current)),
    is.TF(across.lines),
    across.lines || length(target) == length(current)
  )
  # Compute the char by char diffs for each line

  reg <- "-?\\d+(\\.\\d+)?(e-?\\d{1,3})?|\\w+|\\d+|[^[:alnum:]_[:blank:]]+"
  tar.reg <- gregexpr(reg, target)
  cur.reg <- gregexpr(reg, current)

  tar.split <- regmatches(target, tar.reg)
  cur.split <- regmatches(current, cur.reg)

  # Collapse into one line if we want to do the diff across lines, but record
  # item counts so we can reconstitute the lines at the end

  if(across.lines) {
    tar.lens <- vapply(tar.split, length, integer(1L))
    cur.lens <- vapply(cur.split, length, integer(1L))

    tar.split <- list(unlist(tar.split))
    cur.split <- list(unlist(cur.split))
  }
  diffs <- mapply(
    char_diff, tar.split, cur.split, MoreArgs=list(white.space=white.space),
    SIMPLIFY=FALSE
  )
  # Color

  tar.colored <- lapply(
    seq_along(tar.split),
    function(i)
      diff_color(
        tar.split[[i]], tarDiff(diffs[[i]]), seq_along(tar.split[[i]]), "red"
      )
  )
  cur.colored <- lapply(
    seq_along(cur.split),
    function(i)
      diff_color(
        cur.split[[i]], curDiff(diffs[[i]]), seq_along(cur.split[[i]]), "green"
      )
  )
  # Reconstitute lines if needed

  if(across.lines) {
    tar.colored <- split(
      tar.colored[[1L]], rep(seq_along(tar.lens), tar.lens)
    )
    cur.colored <- split(
      cur.colored[[1L]], rep(seq_along(cur.lens), cur.lens)
    )
  }
  # Merge back into original

  regmatches(target, tar.reg) <- tar.colored
  regmatches(current, cur.reg) <- cur.colored

  list(target=target, current=current)
}
# Apply line colors

diff_color <- function(txt, diffs, range, color) {
  stopifnot(
    is.character(txt), is.logical(diffs), !any(is.na(diffs)),
    length(txt) == length(diffs), is.integer(range), !any(is.na(range)),
    all(range > 0 & range <= length(txt)), is.chr1(color)
  )
  to.color <- diffs & seq_along(diffs) %in% range
  txt[to.color] <- clr(txt[to.color], color)
  txt
}
#' Show Diffs Between the Screen Display Versions of Two Objects
#'
#' Designed to highlight at a glance the \bold{display} differences between
#' two objects.  Lack of visual differences is not guarantee that the objects
#' are the same.  These functions are designed to help you quickly understand
#' the nature of differences between objects when they are known to be different
#' (e.g. not \code{identical} or \code{all.equal}).  The diff algorithms are far
#' from perfect and in some cases will likely make seemingly odd choices on what
#' to highlight as being different.
#'
#' These functions focus on the first display difference between two objects.
#' If you want to see the full object diff try \code{\link{Rdiff_obj}}.
#'
#' \itemize{
#'   \item \code{diff_print} shows the differences in the \code{print} or
#'     \code{show} screen output of the two objects
#'   \item \code{diff_str} shows the differences in the \code{str} screen output
#'     of the two objects; will show as many recursive levels as possible so
#'     long as context lines are not exceeded, and if they are, as few as
#'     possible to show at least one error (see \code{max.level})
#'   \item \code{diff_obj} picks between \code{diff_print} and \code{diff_str}
#'     depending on which one it thinks will provide the most useful diff
#' }
#' @note: differences shown or reported by these functions may not be the
#'   totality of the differences between objects since display methods may not
#'   display all differences.  This is particularly true when using \code{str}
#'   for comparisons with \code{max.level} since differences inside unexpanded
#'   recursive levels will not be shown at all.
#' @export
#' @param target the reference object
#' @param current the object being compared to \code{target}
#' @param context 2 length integer vector representing how many lines of context
#'   are shown on either side of differences.  The first value is the maximum
#'   before we start trimming output.  The second value is the maximum to be
#'   shown before we start trimming.  We will always attempt to show as much as
#'   \code{2 * context + 1} lines of output so context may not be centered if
#'   objects display as less than \code{2 * context + 1} lines.
#' @param white.space TRUE or FALSE, whether to consider differences in
#'   horizontal whitespace (i.e. spaces and tabs) as differences (defaults to
#'   FALSE)
#' @param max.level integer(1L) up to how many levels to try running \code{str};
#'   \code{str} is run repeatedly starting with \code{max.level=1} and then
#'   increasing \code{max.level} until we fill the context or a difference
#'   appears or the \code{max.level} specified here is reached.  If the value is
#'   reached then will let \code{str} run with \code{max.level} unspecified.
#'   This is designed to produce the most compact screen output possible that
#'   shows the differences between objects, though obviously it comes at a
#'   performance cost; set to 0 to disable
#' @return character, invisibly, the text representation of the diff

diff_obj <- function(target, current, context=NULL, white.space=FALSE) {
  context <- check_context(context)
  frame <- parent.frame()
  width <- getOption("width")

  diff_obj_internal(
    target, current, tar.exp=substitute(target), cur.exp=substitute(current),
    context=context, frame=frame, width=width, white.space=white.space
  )
}
#' @rdname diff_obj
#' @export

diff_print <- function(target, current, context=NULL, white.space=FALSE) {
  context <- check_context(context)
  width <- getOption("width")
  frame <- parent.frame()
  res <- as.character(
    diff_print_internal(
      target, current, tar.exp=substitute(target), frame=frame,
      cur.exp=substitute(current), context=context, width=width,
      white.space=white.space
    ),
    context=context,
    width=width
  )
  cat(res, sep="\n")
  invisible(res)
}
#' @rdname diff_obj
#' @export

diff_str <- function(
  target, current, context=NULL, white.space=FALSE, max.level=10
) {
  width <- getOption("width")
  frame <- parent.frame()
  res <- as.character(
    diff_str_internal(
      target, current, tar.exp=substitute(target),
      cur.exp=substitute(current), context=context, width=width,
      frame=frame, max.lines=NULL, max.level=max.level,
      white.space=white.space
    ),
    context=context,
    width=width
  )
  cat(res, sep="\n")
  invisible(res)
}
# Implements the diff_* functions
#
# @keywords internal
# @inheritParams diff_obj
# @param tar.exp the substituted target expression
# @param cur.exp the substituted current expression
# @param width at what width to wrap output
# @param file whether to show to stdout or stderr
# @param frame what frame to capture in, relevant mostly if looking for a print
#   method

diff_print_internal <- function(
  target, current, tar.exp, cur.exp, context, width, frame, white.space
) {
  # capture normal prints, along with default prints to make sure that if we
  # do try to wrap an atomic vector print it is very likely to be in a format
  # we are familiar with and not affected by a non-default print method
  if(!is.TF(white.space))
    stop("Argument `white.space` must be TRUE or FALSE")

  both.at <- is.atomic(current) && is.atomic(target)
  cur.capt <- obj_capt(current, width - 3L, frame)
  cur.capt.def <- if(both.at) obj_capt(current, width - 3L, frame, default=TRUE)
  tar.capt <- obj_capt(target, width - 3L, frame)
  tar.capt.def <- if(both.at) obj_capt(target, width - 3L, frame, default=TRUE)

  # Run basic diff

  diffs <- char_diff(tar.capt, cur.capt, white.space=white.space)

  new(
    "diffrDiff", tar.capt=tar.capt, cur.capt=cur.capt,
    tar.exp=tar.exp, cur.exp=cur.exp, diffs=diffs, mode="print",
    tar.capt.def=tar.capt.def, cur.capt.def=cur.capt.def
  )
}
diff_str_internal <- function(
  target, current, tar.exp, cur.exp, context, width, frame, max.lines,
  max.level=10, white.space
) {
  context <- check_context(context)
  if(is.null(max.lines)) {
    max.lines <- context[[1L]] * 2L + 1L
  } else if(!is.int.1L(max.lines) || !max.lines)
    stop("Argument `max.lines` must be integer(1L) and not zero.")
  if(max.lines < 0) max.lines <- Inf
  if(!is.int.1L(max.level))
    stop("Argument `max.level` must be integer(1L) and GTE zero.")
  if(max.level > 100)
    stop("Argument `max.level` cannot be greater than 100")
  if(!is.TF(white.space))
    stop("Argument `white.space` must be TRUE or FALSE")

  obj.add.capt.str <- obj.rem.capt.str <- obj.add.capt.str.prev <-
    obj.rem.capt.str.prev <- character()

  prev.lvl <- 0L
  lvl <- 1L
  repeat{
    if(lvl > 100) lvl <- NA # safety valve
    obj.add.capt.str <-
      obj_capt(current, width - 3L, frame, mode="str", max.level=lvl)
    obj.rem.capt.str <-
      obj_capt(target, width - 3L, frame, mode="str", max.level=lvl)
    str.len.min <- min(length(obj.add.capt.str), length(obj.rem.capt.str))
    str.len.max <- max(length(obj.add.capt.str), length(obj.rem.capt.str))

    # Overshot full displayable size; check to see if previous iteration had
    # differences

    if(str.len.max > max.lines && lvl > 1L && any(diffs.str)) {
      obj.add.capt.str <- obj.add.capt.str.prev
      obj.rem.capt.str <- obj.rem.capt.str.prev
      break
    }
    # Other break conditions

    if(is.na(lvl) || lvl >= max.level) break
    if(
      identical(obj.add.capt.str.prev, obj.add.capt.str) &&
      identical(obj.rem.capt.str.prev, obj.rem.capt.str)
    ) {
      lvl <- prev.lvl
      break
    }
    # Run differences and iterate

    diffs.str <- char_diff(obj.rem.capt.str, obj.add.capt.str, white.space)
    obj.add.capt.str.prev <- obj.add.capt.str
    obj.rem.capt.str.prev <- obj.rem.capt.str
    prev.lvl <- lvl
    lvl <- lvl + 1
  }
  diffs <- char_diff(obj.rem.capt.str, obj.add.capt.str, white.space)
  tar.exp <- call("str", tar.exp, max.level=lvl)
  cur.exp <- call("str", cur.exp, max.level=lvl)
  new(
    "diffrDiff", tar.capt=obj.rem.capt.str, cur.capt=obj.add.capt.str,
    tar.exp=tar.exp, cur.exp=cur.exp, diffs=diffs, mode="str"
  )
}
# Unlike diff_print_internal and diff_str_internal, this one prints to screen
# and invisibly returns the result

diff_obj_internal <- function(
  target, current, tar.exp=substitute(target),
  cur.exp=substitute(current), context=NULL, width=NULL,
  frame=parent.frame(), max.level=10L, file=stdout(), white.space
) {
  context <- check_context(context)
  width <- check_width(width)
  if(!isTRUE(file.err <- is.open_con(file, writeable=TRUE)))
    stop("Argument `file` is not valid because: ", file.err)
  if(!is.environment(frame)) stop("Argument `frame` must be an environment.")

  res.print <- diff_print_internal(
    target, current, tar.exp=tar.exp, cur.exp=cur.exp, context=context,
    width=width, frame=frame, white.space=white.space
  )
  len.print <- max(length(res.print@tar.capt), length(res.print@cur.capt))

  res.str <- diff_str_internal(
    target, current, tar.exp=tar.exp,
    cur.exp=cur.exp, context=context, width=width,
    frame=frame, max.lines=len.print, white.space=white.space
  )
  len.max <- context[[1L]] * 2 + 1
  len.str <- max(length(res.str@tar.capt), length(res.str@cur.capt))

  # Choose which display to use; only favor res.str if it really is substantially
  # more compact and it does show an error and not possible to show full print
  # diff in context

  res <- if(
    (len.print <= len.max && any(res.print)) ||
    !any(res.str) ||
    (len.print < len.str * 3 && len.str > len.max)
  )
    res.print else res.str

  res.chr <- as.character(res, context, width=width)
  cat(res.chr, file=file, sep="\n")
  invisible(res.chr)
}

# Function to check arguments that can also be specified as options when set
# to NULL

check_context <- function(context) {
  err.msg <- cc(
    "must be integer(2L), positive, non-NA, with first value greater than ",
    "second"
  )
  if(is.null(context)) {
    context <- getOption("diffr.test.fail.context.lines")
    if(!is.context.out.vec(context))
      stop("`getOption(\"diffr.test.fail.context.lines\")`", err.msg)
  }
  if(!is.context.out.vec(context)) stop("Argument `context` ", err.msg)
  as.integer(context)
}
check_width <- function(width) {
  err.msg <- "must be integer(1L) and strictly positive"
  if(is.null(width)) {
    width <- getOption("width")
    if(!is.int.pos.1L(width))
      stop("`getOption(\"width\")` ", err.msg)
  }
  if(!is.int.pos.1L(width)) stop("Argument `width` ", err.msg)
  width
}
#' a \code{tools::Rdiff} Between R Objects
#'
#' Just a wrapper that saves the \code{print} / \code{show} representation of an
#' object to a temp file and then runs \code{tools::Rdiff} on them.  For
#' each of \code{from}, \code{to}, will check if they are 1 length character
#' vectors referencing an RDS file, and will use the contents of that RDS file
#' as the object to compare.
#'
#' @export
#' @seealso \code{tools::Rdiff}
#' @param from an R object (see details)
#' @param to another R object (see details)
#' @param ... passed on to \code{Rdiff}
#' @return whatever \code{Rdiff} returns

Rdiff_obj <- function(from, to, ...) {
  dummy.env <- new.env()  # used b/c unique object
  files <- try(
    vapply(
      list(from, to),
      function(x) {
        if(is.chr1(x) && file_test("-f", x)) {
          rdstry <- tryCatch(readRDS(x), error=function(x) dummy.env)
          if(!identical(rdstry, dummy.env)) x <- rdstry
        }
        f <- tempfile()
        capture.output(if(isS4(x)) show(x) else print(x), file=f)
        f
      },
      character(1L)
  ) )
  if(inherits(files, "try-error"))
    stop("Unable to store text representation of objects")
  res <- tools::Rdiff(files[[1L]], files[[2L]], ...)
  unlink(files)
  invisible(res)
}
obj_capt <- function(
  obj, width=getOption("width"), frame=parent.frame(), mode="print",
  max.level=0L, default=FALSE
) {
  if(!is.numeric(width) || length(width) != 1L)
    stop("Argument `width` must be a one long numeric/integer.")
  if(!is.chr1(mode) || !mode %in% c("print", "str"))
    stop("Argument `mode` must be one of \"print\" or \"str\"")
  # note this forces eval, which is needed
  if(!is.environment(frame))
    stop("Argument `frame` must be an environment")
  if(!is.na(max.level) && (!is.int.1L(max.level) ||  max.level < 0))
    stop("Argument `max.level` must be integer(1L) and positive")

  width.old <- getOption("width")
  on.exit(options(width=width.old))
  width <- max(width, 10L)
  options(width=width)

  if(identical(mode, "print")) {
    obj.out <- capture.output(
      invisible(print.res <- user_exp_display(obj, frame, quote(obj), default))
    )
  } else if(identical(mode, "str")) {
    obj.out <- capture.output(
      invisible(
        print.res <-
          user_exp_str(obj, frame, quote(obj), max.level)
    ) )
  } else stop("Logic Error: unexpected mode; contact maintainer.")

  options(width=width.old)
  on.exit(NULL)
  # remove trailing spaces; shouldn't have to do it but doing it since legacy
  # tests remove them and PITA to update those

  obj.out <- sub("\\s*$", "", obj.out)

  if(print.res$aborted) {  # If failed during eval retrieve conditions
    err.cond <-
      which(vapply(print.res$conditions, inherits, logical(1L), "error"))
    err.type <- if(identical(mode, "str")) "str"
      else if(identical(mode, "print"))
        if(isS4(obj)) "show" else "print"
      else stop("Logic Error: cannot figure out print mode; contact maintainer.")
    err.cond.msg <- if(length(err.cond)) {
      c(
        paste0(
          "<Error in ", err.type,
          if(is.object(obj))
            paste0(" method for object of class \"", class(obj)[[1L]], "\""),
          ">"
        ),
        paste0(
          conditionMessage(print.res$conditions[[err.cond[[1L]]]]), collapse=""
      ) )
    } else ""
    obj.out <- c(obj.out, err.cond.msg)
  }

  obj.out
}
# constructs the full diff message with additional meta information

obj_screen_chr <- function(
  obj.chr, obj.name, diffs, range, width, pad, color=NA_character_
) {
  stopifnot(is.chr1(pad))
  pre <- post <- NULL
  pad.all <- pad.pre.post <- NULL
  obj.name.dep <- deparse(obj.name)[[1L]]
  extra <- character()
  len.obj <- length(obj.chr)

  if(len.obj) {
    pad.all <- character(len.obj)
    pad.chars <- nchar(pad)
    if(!any(diffs)) {
      pad.all <- replicate(len.obj, cc(rep(" ", pad.chars)))
    } else {
      pad.all[diffs] <- pad
      pad.all <- format(pad.all)
    }
    pad.all[diffs] <- clr(pad.all[diffs], color)
    pad.pre.post <- paste0(rep(" ", pad.chars), collapse="")

    omit.first <- max(min(range[[1L]] - 1L, len.obj), 0L)
    omit.last <- max(len.obj - tail(range, 1L), 0L)
    diffs.last <- sum(tail(diffs, -tail(range, 1L)))

    if(omit.first)
      pre <- paste0(
        "~~ omitted ", omit.first, " line", if(omit.first != 1L) "s",
        " w/o diffs"
      )
    if(omit.last) {
      post <- paste0(
        "~~ omitted ", omit.last, " line", if(omit.last != 1L) "s",
        if(diffs.last) cc(" w/ ", diffs.last, " diff") else " w/o diff",
        if(diffs.last != 1L) "s"
    ) }
    if(!is.null(post)) {
      post <- clr(
        paste0(
          pad.pre.post,
          word_wrap(paste0(post, extra, " ~~"), width - pad.chars)
        ),
        "silver"
    ) }
    if (!is.null(pre)) {
      pre <- clr(
        paste0(
          pad.pre.post,
          word_wrap(
            paste0(pre, if(is.null(post)) extra, " ~~"), width - pad.chars
        ) ),
        "silver",
    ) }
  }
  c(
    clr(paste0("@@ ", obj.name.dep, " @@"), "cyan"),
    paste0(
      c(pre, paste0(pad.all, obj.chr)[range[range <= len.obj]], post)
    )
  )
}