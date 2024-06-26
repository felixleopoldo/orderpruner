iterativeMCMCplus1 <- function(param, iterations, stepsave, plus1it = NULL, MAP = TRUE, posterior = 0.5,
                             startorder = NULL, moveprobs, softlimit = 9, hardlimit = 14, chainout = FALSE,
                             scoreout = FALSE, startspace = NULL, blacklist = NULL, gamma = 1, verbose = FALSE, alpha = NULL,
                             cpdag = FALSE, mergecp = "skeleton", addspace = NULL, scoretable = NULL,
                             accum) {
  n <- param$n
  nsmall <- param$nsmall
  matsize <- ifelse(param$DBN, n + nsmall, n)


  objsizes <- list()
  maxlist <- list()
  maxobj <- list()
  updatenodeslist <- list()
  MCMCtraces <- list()

  if (!param$DBN) {
    if (param$bgn != 0) {
      updatenodes <- c(1:n)[-param$bgnodes]
    } else {
      updatenodes <- c(1:n)
    }
  } else {
    updatenodes <- c(1:nsmall)
  }

  if (is.null(blacklist)) {
    blacklist <- matrix(0, nrow = matsize, ncol = matsize)
  }

  diag(blacklist) <- 1

  if (!is.null(param$bgnodes)) {
    for (i in param$bgnodes) {
      blacklist[, i] <- 1
    }
  }

  #defining startskel
  if (!is.null(scoretable)) {
    startskel <- scoretable$adjacency
    blacklist <- scoretable$blacklist
    scoretable <- scoretable$tables
  } else {
    if (is.null(startspace)) {
      startspace <- definestartspace(alpha, param, cpdag = cpdag, algo = "pc")
    }
    startskeleton <- 1 * (startspace & !blacklist)
    if (!is.null(addspace)) {
      startskel <- 1 * ((addspace | startskeleton) & !blacklist)
    } else { startskel <- startskeleton }
  }

  blacklistparents <- list()
  for (i in 1:matsize) {
    blacklistparents[[i]] <- which(blacklist[, i] == 1)
  }

  if (verbose) {
    cat(paste("maximum parent set size is", max(apply(startskel, 2, sum))), "\n")
  }
  if (max(apply(startskel, 2, sum)) > hardlimit) {
    stop("the size of maximal parent set is higher that the hardlimit; redifine the search space or increase the hardlimit!")
  }


  starttimeall <- Sys.time()
  maxorder <- startorder


  ptab <- listpossibleparents.PC.aliases(startskel, isgraphNEL = FALSE, n, updatenodes)


  if (verbose) {
    cat("skeleton ready \n")
    flush.console()
  }
  ##################################
  #calculating initial score tables#
  ##################################

  parenttable <- ptab$parenttable # basic parenttable without plus1 lists
  aliases <- ptab$aliases #aliases for each node since all nodes in parent tables are done as 1,2,3,4... not real parent names
  numberofparentsvec <- ptab$numberofparentsvec
  numparents <- ptab$numparents
  plus1lists <- PLUS1(matsize, aliases, updatenodes, blacklistparents)
  rowmaps <- parentsmapping(parenttable, numberofparentsvec, n, updatenodes)

  if (is.null(scoretable)) {
    scoretable <- scorepossibleparents.PLUS1(parenttable = parenttable, plus1lists = plus1lists,
                                             n = n, param = param, updatenodes = updatenodes,
                                             rowmaps, numparents, numberofparentsvec)
  }

  posetparenttable <- poset(parenttable, numberofparentsvec, rowmaps, n, updatenodes)

  if (MAP == TRUE) {
    maxmatrices <- posetscoremax(posetparenttable, scoretable, numberofparentsvec,
                                 rowmaps, n, plus1lists = plus1lists, updatenodes)
    endtimetab <- Sys.time()
  } else {
    bannedscore <- poset.scores(posetparenttable, scoretable, ptab$numberofparentsvec, rowmaps,
                                n, plus1lists = plus1lists, ptab$numparents, updatenodes)
    endtimetab <- Sys.time()
  }
  oldadj <- startskeleton

  ############
  #MCMC chain#  
  ############

  i <- 1
  if (is.null(plus1it)) plus1it <- 100
  while (length(updatenodes) > 0 & i <= plus1it) {
    #print("Plus1 iteration Felix edited version to update info (score tables etc) after each iteration.")
    starttimeit <- Sys.time()
    if (i > 1) {
      newptab <- listpossibleparents.PC.aliases(newadj, isgraphNEL = FALSE, n, updatenodes)
      
      parenttable[updatenodes] <- newptab$parenttable[updatenodes] # basic parenttable without plus1 lists
      aliases[updatenodes] <- newptab$aliases[updatenodes] #aliases for each node since all nodes in parent tables are done as 1,2,3,4... not real parent names
      numberofparentsvec[updatenodes] <- newptab$numberofparentsvec[updatenodes]
      numparents[updatenodes] <- newptab$numparents[updatenodes]
      
      # Updating ptab / Felix
      ptab$parenttable <- parenttable
      ptab$aliases <- aliases
      ptab$numberofparentsvec <- numberofparentsvec
      ptab$numparents <- numparents

      newplus1lists <- PLUS1(matsize, aliases, updatenodes, blacklistparents)
      plus1lists$mask[updatenodes] <- newplus1lists$mask[updatenodes]
      plus1lists$parents[updatenodes] <- newplus1lists$parents[updatenodes]
      plus1lists$aliases[updatenodes] <- newplus1lists$aliases[updatenodes]
      rowmaps[updatenodes] <- parentsmapping(parenttable, numberofparentsvec, n, updatenodes)[updatenodes]
      scoretable[updatenodes] <- scorepossibleparents.PLUS1(parenttable, plus1lists, n, param, updatenodes, rowmaps, numparents, numberofparentsvec)[updatenodes]
      posetparenttable[updatenodes] <- poset(parenttable, numberofparentsvec, rowmaps, n, updatenodes)[updatenodes]

      if (MAP) {
        newmaxmatrices <- posetscoremax(posetparenttable, scoretable, numberofparentsvec,
                                          rowmaps, n, plus1lists = plus1lists, updatenodes)
        maxmatrices$maxmatrix[updatenodes] <- newmaxmatrices$maxmatrix[updatenodes]
        maxmatrices$maxrow[updatenodes] <- newmaxmatrices$maxrow[updatenodes]

      } else {
        newbannedscore <- poset.scores(posetparenttable, scoretable, numberofparentsvec, rowmaps,
                                         n, plus1lists = plus1lists, numparents, updatenodes)
        bannedscore[updatenodes] <- newbannedscore[updatenodes]
      }

      if (verbose) {
        cat(paste("MCMC plus1 iteration", i, "\n"))
        flush.console()
      }
    } else {
      if (verbose) {
        cat(paste("score tables completed, MCMC plus1 starts", "\n"))
        flush.console()
      }
    }
    if (MAP) {
      starttimemcmc <- Sys.time()
      MCMCresult <- orderMCMCplus1max(n, nsmall, startorder, iterations, stepsave, moveprobs, parenttable,
                                        scoretable, aliases, numparents, rowmaps, plus1lists, maxmatrices, numberofparentsvec,
                                        gamma = gamma, bgnodes = param$bgnodes, matsize = matsize)
      endtimeit <- Sys.time()
      if (verbose) {
        cat(endtimeit - starttimeit, "\n")
        flush.console()
      }
    } else {
      starttimemcmc <- Sys.time()
      MCMCresult <- orderMCMCplus1(n, nsmall, startorder, iterations, stepsave, moveprobs, parenttable,
                                     scoretable, aliases, numparents, rowmaps, plus1lists,
                                     bannedscore, numberofparentsvec, gamma = gamma, bgnodes = param$bgnodes,
                                     matsize = matsize)
      endtimeit <- Sys.time()
      if (verbose) {
        cat(endtimeit - starttimeit, "\n")
        flush.console()
      }
    }


    MCMCtraces$DAGscores[[i]] <- MCMCresult$DAGscores

    if (chainout) {
      if (param$DBN) {
        MCMCtraces$incidence[[i]] <- lapply(MCMCresult$incidence, function(x) DBNtransform(x, param = param))
        MCMCtraces$orders[[i]] <- lapply(MCMCresult$orders, order2var, varnames = param$firstslice$labels)
      } else {
        MCMCtraces$incidence[[i]] <- lapply(MCMCresult$incidence, function(x) assignLabels(x, param$labels))
        MCMCtraces$orders[[i]] <- lapply(MCMCresult$orders, order2var, varnames = param$labels)
      }
      MCMCtraces$orderscores[[i]] <- MCMCresult$orderscores
    }

    maxobj <- storemaxMCMC(MCMCresult, param)
    maxlist[[i]] <- maxobj

    maxN <- which.max(MCMCresult$DAGscores)

    if (i > 1) {
      if (maxobj$score > maxscore) {
        maxDAG <- maxobj$DAG
        maxorder <- maxobj$order
        maxscore <- maxobj$score
        maxit <- i
      }
    } else {
      maxDAG <- maxobj$DAG
      maxscore <- maxobj$score
      maxorder <- maxobj$order
      maxit <- 1
    }
    if (MAP) {
      newadj <- newspacemap(n, startskeleton, oldadj, softlimit, hardlimit, blacklist,
                               maxN = maxN, MCMCtrace = MCMCresult[[1]], mergetype = mergecp,
                               accum = accum)
    } else {
      newadj <- newspaceskel(n, startskeleton, oldadj, softlimit, hardlimit, posterior,
                                blacklist, MCMCtrace = MCMCresult[[1]], mergetype = mergecp)
    }
    updatenodes <- which(apply(newadj == oldadj, 2, all) == FALSE)
    updatenodeslist[[i]] <- updatenodes
    
   
    startorder <- c(MCMCresult$orders[[maxN]], param$bgnodes)
    i <- i + 1
    # Felix added
    if(length(updatenodes) > 0 & i <= plus1it){ 
      oldadj <- newadj
    }
  }


  addedge <- sum(newadj) - sum(startskeleton)
  endtimeall <- Sys.time()

  #attr(MCMCtraces$DAGscores,"class")<-"MCMCtracemult"
  result <- list()
  if (scoreout) {
    if (chainout) { output <- 4 }
    else { output <- 3 }
  } else {
    if (chainout) { output <- 2 }
    else { output <- 1 }
  }
  result$maxtrace <- maxlist
  #result$max<-maxlist[[length(maxlist)]]

  result$DAG <- maxobj$DAG
  result$CPDAG <- graph2m(dag2cpdag(m2graph(result$DAG)))
  result$score <- maxobj$score
  result$maxorder <- maxobj$order

  result$trace <- MCMCtraces$DAGscores
  MCMCtraces$DAGscores <- NULL

  if (param$DBN) {
    result$startspace <- DBNtransform(startskeleton, param)
    result$endspace <- DBNtransform(oldadj, param)
  } else {
    result$startspace <- startskeleton
    result$endspace <- oldadj
  }
  switch(as.character(output),
           "1" = {
    # return only maximum DAG and order
    # do not need to do anything else
  },
           "2" = {
    # return all MCMC all saved MCMC steps: incidence, DAGscore, orderscore and order and max result
    result$traceadd <- MCMCtraces
  },
           "3" = {
    # return max DAG, order, last search space incidence and all scoretables
    result$scoretable <- list()
    result$scoretable$adjacency <- result$endspace
    result$scoretable$tables <- scoretable
    result$scoretable$blacklist <- blacklist
    attr(result$scoretable, "class") <- "MCMCscoretab"
  },
           "4" = {
    # return all MCMC all saved MCMC steps,max result,last search space and scoretables
    result$traceadd <- MCMCtraces
    result$scoretable <- list()
    result$scoretable$adjacency <- result$endspace
    result$scoretable$tables <- scoretable
    result$scoretable$blacklist <- blacklist
    attr(result$scoretable, "class") <- "MCMCscoretab"
  }
    )
    
  # This part is added by Felix. it is needed in cpp for computing the order score tables.
  ret <- list()
  if (MAP == TRUE) {
    ret$bannedscore <- maxmatrices$maxmatrix
  } else {
    ret$bannedscore <- bannedscore
  }


  ret$plus1lists <- plus1lists
  ret$rowmaps <- rowmaps
  ret$ptab <- ptab  
  ret$result <- result # This was previuosly return(result) //Felix
  ret$maxmatrices <- maxmatrices # This should be used for finding best DAGs

  return(ret)
}
