import sys

from LOGISTIC_REGRESSION.logistic_regression import LogisticRegression

def main(args):
    LogisticRegression(args[1:]).local_step()

if __name__ == "__main__":
    LogisticRegression(sys.argv[1:]).local_step()
