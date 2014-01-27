likelihood
==========

Shot Likelihood - Matt Redfield

fg_prediction.rb : Main ruby script for assessing likelihood of a shot being made

evaluation.rb : Evaluating the accuracy of the likelihood function with increasing shot history

results.csv : shot and likelihood results from fg_prediction.rb

trend.csv(5) : accuracy for each 1000 (or 5000) shots calculated as the sumproduct of predicted likelihood and result     (best case is that you predict 100% likelihood for all makes and 0% likelihood for all misses) maximum score is 1 per shot

accuracy_over_time : Graph of increasing accuracy trend with increased shot history.


Evaluation
==========
This likelihood function was built upon the principle that the determining factors for shot results, in order of decreasing importance, are shot type (layup or turnaround jumpshot), player (Shaq or Kobe), and location (left corner or right corner).  Therefore the strategy was to keep a comprehensive database of all shot attempts and results and relax first the location of the shot and then the player shooting the shot in order to have a sufficient number of past results.

Because 50 was used as the threshold to stop looking for more past results, there was a steep increase in accuracy until that threshold was reached, and after that point the accuracy increased at a much slower rate.  The highest accuracy achieved was 572 (out of 1000) which was the sum of all the likelihoods on makes and the complements of all the likelihoods on misses.
