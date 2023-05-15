source("R/scoring.R")
source("R/opruner.r") 

filename <- "data/p20n300gaussdata.csv"
data <- read.csv(filename, check.names = FALSE)

scoretype <- "bge"
bgepar <- list(am=1, aw=NULL)

if (scoretype =="bge") {
    bidag_scores <- BiDAG::scoreparameters(scoretype = scoretype, data, bgepar = bgepar)
} else if (scoretype == "bde") {
    bidag_scores <- BiDAG::scoreparameters(scoretype = scoretype, data[-1, ], bdepar = bdepar)
}
set.seed(1)
cpp_friendly_scores <- get_plus1_score_essentials_for_cpp(bidag_scores, plus1it=2, iterations=NULL) # from iterativeMCMC

opr <- optimal_order(cpp_friendly_scores)
adjmat <- optimal_dag(bidag_scores, cpp_friendly_scores$space, opr$order)
colnames(adjmat) <- colnames(data)