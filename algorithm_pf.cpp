//============================================================================
// MCKL/example/algorithm/src/algorithm_pf.cpp
//----------------------------------------------------------------------------
// MCKL: Monte Carlo Kernel Library
//----------------------------------------------------------------------------
// Copyright (c) 2013-2018, Yan Zhou
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
//   Redistributions of source code must retain the above copyright notice,
//   this list of conditions and the following disclaimer.
//
//   Redistributions in binary form must reproduce the above copyright notice,
//   this list of conditions and the following disclaimer in the documentation
//   and/or other materials provided with the distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS AS IS
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.
// ============================================================================

//#include "algorithm_pf.hpp"
#include <RInside.h>
#include <Rcpp.h>
#include "smc_stuff.cpp"
#include "thread_pool.hpp"
#include <experimental/any>

int main(int argc, char **argv)
{

    // R["txt"] = "Hello, world!\n"; // assign a char* (string) to 'txt'
    // R.parseEvalQ("print(txt)");
    --argc;
    ++argv;

    std::size_t N = 3;
    if (argc > 0)
    {
        N = static_cast<std::size_t>(std::atoi(*argv));
        --argc;
        ++argv;
    }

    // Can we maybe draw N bootstrap samples at each stage? So that the number of particle are fixed?
    // Can we use the sampled ones as a prior that is approximately the same?
    //std::string r_code = "ret <- readRDS('data/myvstructdata.csv.rds'); ret"; // Do this in R instead?
    std::string r_code = "ret <- readRDS('data/p20n300gaussdata.csv.rds'); ret"; // Do this in R instead?
    //std::string r_code = "ret <- readRDS('data/p50n300gaussdata.csv.rds'); ret"; // Do this in R instead?
    //std::string r_code = "ret <- readRDS('data/jackdata.csv.rds'); print(ret$bannedscore); print('aliases'); print(ret$aliases); print('rowmaps_backwards'); print(ret$rowmaps_backwards); ret";
    //std::string r_code = "ret <- readRDS('data/myasiandata.csv.rds'); print(ret$bannedscore); print('aliases'); print(ret$aliases); print('rowmaps_backwards'); print(ret$rowmaps_backwards); print('potential plus1 parents'); print(ret$plus1listsparents); ret";
    //std::string r_code = "ret <- readRDS('data/myasiandata.csv.rds'); ret";

    RInside R(argc, argv);
    //std::string r_code = "source(\"readtables.R\"); ret";
    Rcpp::List ret = R.parseEval(r_code);
    OrderScoring scoring = get_score(ret);

    int seed = 1;
    std::srand(seed);
    std::random_device rd;
    std::mt19937 gen(rd());
    std::default_random_engine generator(seed);

    // std::vector<std::vector<bool>> mats;
    // mats.push_back({1, 1, 1, 1}); // 0
    // mats.push_back({1, 1, 0, 0}); // 1
    // mats.push_back({0, 1, 0, 0});
    // mats.push_back({0, 1, 0, 0}); // 3
    // mats.push_back({0, 1, 0, 1}); // 4
    // mats.push_back({1, 1, 0, 0});

    // std::vector<double> order_scores = {1.0, 2.0, 2.1, 3.0, 2.5, 0.5};
    // std::vector<int> pruned_inds = unique_sets(mats, order_scores);
    
    // PrintVector(pruned_inds);
    // std::cout << DBL_EPSILON << std::endl
    //sequential_opt_left_type(scoring);
    sequential_opt(scoring);
    //std::cout << definitelyGreaterThan(0.0003, 0.0002, 0.001) << std::endl;

    // int M = 100000000;
    // const auto &[max_order, mh_log_scores] = mh(M, scoring, generator);
    // int mh_max_score_ind = std::max_element(mh_log_scores.begin(), mh_log_scores.end()) - mh_log_scores.begin();
    // std::cout << "MH only swap move " << M << " iterations" << std::endl;
    // std::cout << "max order" << std::endl;
    // PrintVector(max_order);
    // std::cout << "score: " << mh_log_scores[mh_max_score_ind] << std::endl;

    // thread_pool pool;
    // //pool.push_task(task, arg1, arg2);
    // //pool.wait_for_tasks();

    // const auto &[pgibbs_orders, pgibbs_log_scores] = pgibbs(M, N, scoring, generator, pool);

    // std::cout << "PGibbs log scores " << std::endl;
    // PrintVector(pgibbs_log_scores);

    // for (auto &o : pgibbs_orders)
    // {
    //     PrintVector(o);
    // }
    // int pgibbs_max_score_ind = std::max_element(pgibbs_log_scores.begin(), pgibbs_log_scores.end()) - pgibbs_log_scores.begin();
    // std::cout << "PGibbs max log score " << pgibbs_log_scores[pgibbs_max_score_ind] << std::endl;
}

// auto start = high_resolution_clock::now();
// const auto &[smc_log_w, smc_orders, smc_log_scores] = smc(scoring, N, order.size(), generator);
// auto stop = high_resolution_clock::now();
// auto duration = duration_cast<milliseconds>(stop - start);

// std::vector<double> * norm_w = dist_from_logprobs(smc_log_w);
// std::discrete_distribution<int> distribution(norm_w->begin(), norm_w->end());

// int maxElementIndex = std::max_element(smc_log_scores.begin(), smc_log_scores.end()) - smc_log_scores.begin();

// //PrintVector(log_order_scores[p-1]);
// std::map<std::vector<int>, double> orders_probs;
// std::set<std::vector<int>> distinct_orders;

// for (int i = 0; i < N; i++)
// {
//     distinct_orders.insert(smc_orders[i]);
// }

// for (int i = 0; i < N; i++)
// {
//     if (orders_probs.count(smc_orders[i]))
//     {
//         orders_probs[smc_orders[i]] += (*norm_w)[i];
//     }
//     else
//     {
//         orders_probs[smc_orders[i]] = (*norm_w)[i];
//     }
// }

// for (auto o : distinct_orders)
// {
//     PrintVector(o);
//     std::vector<double> *scr = scoring.score(o, 0, p);
//     double sc = std::accumulate(scr->begin(), scr->end(), 0.0);
//     //std::cout << orders_probs[o] << " score " << sc << std::endl;
//     delete scr;
// }

// std::cout << "number of distinct orders: " << distinct_orders.size() << std::endl;
// std::cout << "index: " << maxElementIndex << std::endl;
// //PrintVector(new_orders[maxElementIndex]);
// PrintVector(smc_orders[maxElementIndex]);

// //std::cout << "prob: " << orders_probs[new_orders[maxElementIndex]] << std::endl;
// std::cout << "prob: " << orders_probs[smc_orders[maxElementIndex]] << std::endl;
// //std::cout << "score: " << log_order_scores[maxElementIndex] << std::endl;
// std::cout << "score: " << smc_log_scores[maxElementIndex] << std::endl;
// //PrintVector(smc_log_scores);
// // To get the value of duration use the count()
// // member function on the duration object
// std::cout << duration.count() << " ms." << std::endl;
// delete norm_w;
