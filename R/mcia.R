mcia <- function (df.list, cia.nf = 2, cia.scan = FALSE, nsc = T, svd=TRUE) 
{
  df.list <- lapply (df.list, function(x) {
    if (inherits(x, "ExpressionSet")) {
      r <- made4:::getdata(x)
    } else {
      r <- x
    }
    return(r)
  })

  for (i in names(df.list)) {
    df <- df.list[[i]]
    minn <- min(df)
    ind <- apply(df, 1, function(x) all(x == minn))
    if (any(ind)) 
      stop(paste("There are features in data.frame ", i, 
                 " do not\n        expressed in all cases, please remove these features"))
  }
  N <- sapply(df.list, ncol)
  df.list <- lapply(df.list, as.matrix)
  if (length(unique(N)) != 1) 
    stop("Nonequal number of individual across data.frames")
  infi <- sapply(df.list, function(x) any(is.infinite(x)))
  if (any(infi)) 
    stop("Infinite numeric in the data.frames")
  na <- sapply(df.list, function(x) any(is.na(x)))
  if (any(na)) 
    stop("NAs in the data.frames")
  if (is.null(names(df.list))) 
    names(df.list) <- paste("df", 1:length(df.list), sep = "")
  
  
  # ====================================
  # ===== lapack function which is called by svd fails to coverage in some cases
  # ===== This function is used to replace svd when this happens
  # =================================
  
  mcoaEnv <- environment(mcoa)
  fakeEnv <- new.env(parent = mcoaEnv)
  mcoa2 <- ade4::mcoa
  environment(mcoa2) <- fakeEnv
  
  if (is.logical(svd)) {
    if (svd)
      assign("svd", base::svd, fakeEnv)
    else 
      assign("svd", function(df) {
                res <- list()
                m <- tcrossprod(df, df)
                em <- eigen(m)
                em$values[em$values < 0] <- 1e-30
                res$d <- sqrt(em$values)
                res$u <- em$vectors
                res$v <- t(apply(t(df) %*% em$vectors, 1, function(x) x/sqrt(em$values)))
                return(res)}, 
             fakeEnv)
  } else
    stop("logical value required for svd")
  # =========================================
  
  if (nsc) {
    df.list <- lapply(df.list, made4::array2ade4, pos = TRUE)
    coa.list <- lapply(df.list, dudi.nsc, scannf = FALSE, nf = cia.nf)
    coa.list.t <- lapply(coa.list, t.dudi)
    ktcoa <- ktab.list.dudi(coa.list.t)
  }
  if (!nsc) {
    df.list <- lapply(df.list, t)
    df.list <- lapply(df.list, made4::array2ade4, pos = TRUE)
    coa1 <- dudi.coa(df.list[[1]], scannf = FALSE, nf = cia.nf)
    coa.list <- lapply(df.list[-1], made4:::dudi.rwcoa, rowweights = coa1$lw, 
                       scannf = FALSE, nf = cia.nf)
    coa.list.name <- names(coa.list)
    coa.list$coa1 <- coa1
    coa.list <- coa.list[c("coa1", coa.list.name)]
    names(coa.list)[1] <- names(df.list)[1]
    for (i in 1:length(coa.list)) {
      coa.list[[i]]$lw <- round(coa.list[[i]]$lw, digits = 8)
    }
    ktcoa <- ktab.list.dudi(coa.list)
  }
  mcoin <- try(mcoa2(X = ktcoa, nf = cia.nf, scannf = FALSE), silent=TRUE) # ...
  if (inherits (mcoin, "try-error")) {
    warning("'svd' fail to convergence, 'eigen' used to performs singular value decomposition")
    assign("svd", function(df) {
              res <- list()
              m <- tcrossprod(df, df)
              em <- eigen(m)
              em$values[em$values < 0] <- 1e-30
              res$d <- sqrt(em$values)
              res$u <- em$vectors
              res$v <- t(apply(t(df) %*% em$vectors, 1, function(x) x/sqrt(em$values)))
              return(res)}, 
            fakeEnv)
    mcoin <- mcoa2(X = ktcoa, nf = cia.nf, scannf = FALSE)
  }
  tab <- scalewt(mcoin$Tco, wt = ktcoa$cw, center = F, scale = T)
  colnames(tab) <- paste("Axis", 1:ncol(tab), sep = "")
  mcoin$Tlw <- ktcoa$lw
  mcoin$Tcw <- ktcoa$cw
  mcoin$blo <- ktcoa$blo
  mcoin$Tc1 <- tab
  call <- match.call()
  mciares <- list(call = call, mcoa = mcoin, coa = coa.list)
  class(mciares) <- "mcia"
  return(mciares)
}