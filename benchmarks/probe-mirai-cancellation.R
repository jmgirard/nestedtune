# T1: what does mirai hand back for each way a run can be stopped?
# Every wait is deadline-bounded and reads $data only once resolved, so no
# probe here can hang (M07 lost 39 minutes of R CMD check to one that could).

library(mirai)

settle <- function(m, deadline = 15) {
  end <- Sys.time() + deadline
  while (unresolved(m) && Sys.time() < end) {
    Sys.sleep(0.05)
  }
  if (unresolved(m)) {
    return(structure(list(), class = "PROBE_TIMED_OUT"))
  }
  m$data
}

describe <- function(label, x) {
  int <- suppressWarnings(tryCatch(as.integer(x), error = function(e) {
    NA_integer_
  }))
  named <- tryCatch(nanonext::nng_error(int), error = function(e) NA_character_)
  msg <- tryCatch(conditionMessage(x), error = function(e) {
    "<conditionMessage() RAISES>"
  })
  data.frame(
    probe = label,
    classes = paste(class(x), collapse = "/"),
    value = int,
    nng_error = named,
    is_error_value = tryCatch(is_error_value(x), error = function(e) NA),
    is_mirai_error = tryCatch(is_mirai_error(x), error = function(e) NA),
    is_condition = inherits(x, "condition"),
    is_interrupt = inherits(x, "miraiInterrupt"),
    cond_message = substr(msg, 1, 40)
  )
}

out <- list()
reset <- function() {
  daemons(0)
  Sys.sleep(0.3)
}

# --- 1. stop_mirai() on a task actively running on a daemon ----------------
reset()
daemons(1)
m <- mirai({
  Sys.sleep(30)
  "done"
})
Sys.sleep(1.5) # let the daemon pick it up
stop_mirai(m)
out[[1]] <- describe("stop_mirai, in-flight", settle(m))

# --- 2. stop_mirai() on a task still queued behind another ----------------
reset()
daemons(1)
busy <- mirai({
  Sys.sleep(30)
  "busy"
})
Sys.sleep(1.5)
queued <- mirai({
  "never runs"
}) # 1 daemon, so this waits
stop_mirai(queued)
out[[2]] <- describe("stop_mirai, queued", settle(queued))
stop_mirai(busy)

# --- 3. daemons(0) while a task is outstanding ----------------------------
reset()
daemons(1)
m <- mirai({
  Sys.sleep(30)
  "done"
})
Sys.sleep(1.5)
daemons(0)
out[[3]] <- describe("daemons(0), in-flight", settle(m))

# --- 4. daemon killed mid-task (RR03's baseline: expected errorValue 19) --
reset()
daemons(1)
m <- mirai({
  tools::pskill(Sys.getpid())
  "unreachable"
})
out[[4]] <- describe("daemon killed mid-task", settle(m))

# --- 5. an ordinary error raised in the task (the other known shape) ------
reset()
daemons(1)
m <- mirai({
  stop("boom")
})
out[[5]] <- describe("error raised in task", settle(m))

# --- 6. the real code path: mirai_map + collect_mirai, one task stopped ---
reset()
daemons(1)
mp <- mirai_map(1:2, function(i) {
  Sys.sleep(30)
  i
})
Sys.sleep(1.5)
stop_mirai(mp)
collected <- tryCatch(collect_mirai(mp), error = function(e) list(e))
for (i in seq_along(collected)) {
  out[[length(out) + 1L]] <- describe(
    paste0("mirai_map stopped [", i, "]"),
    collected[[i]]
  )
}

reset()
res <- do.call(rbind, out)
print(res, right = FALSE)
cat(
  "\nmirai ",
  as.character(packageVersion("mirai")),
  " / nanonext ",
  as.character(packageVersion("nanonext")),
  "\n",
  sep = ""
)
