import logging

from utils.algorithm_utils import PRIVACY_MAGIC_NUMBER

LOGGING_LEVEL_ALG = logging.INFO
LOGGING_LEVEL_SQL = logging.INFO

PRIVACY_THRESHOLD = PRIVACY_MAGIC_NUMBER

P_VALUE_CUTOFF = 0.001
P_VALUE_CUTOFF_STR = "< " + str(P_VALUE_CUTOFF)
CONFIDENCE = 0.95  # used in confidence intervals computations
PREC = 1e-7  # precision for termination of iterative algs
MAX_ITER = 40  # maximum iteration for iterative algs
