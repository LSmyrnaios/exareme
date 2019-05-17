from __future__ import division
from __future__ import print_function

import sys
import sqlite3
from os import path
import os
import errno
from argparse import ArgumentParser

import numpy as np

sys.path.append(path.dirname(path.dirname(path.dirname(path.abspath(__file__)))) + '/utils/')
sys.path.append(path.dirname(path.dirname(path.dirname(path.abspath(__file__)))) + '/LOGISTIC_REGRESSION/')

from algorithm_utils import StateData
from log_regr_lib import LogRegrInit_Loc2Glob_TD


# TODO Missing values (check if works)
# TODO Summary
# TODO Formula Parser
# TODO Dummy coding

def logregr_local_init(local_in):
    # Unpack local input
    X, Y, schema_X, schema_Y = local_in
    n_obs = len(Y)
    n_cols = len(X[0]) + 1  # Add one for the intercept
    schema_X.insert(0, 'Intercept')
    # Create dictionary for categories in Y
    y_val_dict = {
        sorted(set(Y))[0]: 0,
        sorted(set(Y))[1]: 1
    }
    Y = np.array([y_val_dict[yi] for yi in Y], dtype=np.uint8)
    # Add 1's column in X to account for intercept term
    X = np.insert(X, obj=0, values=np.ones(n_obs), axis=1)

    # Pack state and results
    local_state = StateData(X=X, Y=Y)
    local_out = LogRegrInit_Loc2Glob_TD(n_obs, n_cols, y_val_dict, schema_X, schema_Y)
    return local_state, local_out


def main():
    # Parse arguments
    parser = ArgumentParser()
    parser.add_argument('-X', required=True, help='Variable names in X, comma separated.')
    parser.add_argument('-Y', required=True, help='Variable names in Y, comma separated.')
    parser.add_argument('-cur_state_pkl', required=True, help='Path to the pickle file holding the current state.')
    parser.add_argument('-input_local_DB', required=True, help='Path to local db.')
    parser.add_argument('-db_query', required=True, help='Query to be executed on local db.')
    args, unknown = parser.parse_known_args()
    fname_cur_state = path.abspath(args.cur_state_pkl)
    fname_loc_db = path.abspath(args.input_local_DB)
    query = args.db_query
    schema_X = list(set(
            args.X
                .replace(' ', '')
                .split(',')
    ))
    schema_Y = args.Y.strip()

    # Get data from local DB
    conn = sqlite3.connect(fname_loc_db)
    cur = conn.cursor()
    cur.execute(query)
    schema = [description[0] for description in cur.description]
    data = cur.fetchall()
    idx_X = [schema.index(v) for v in schema_X if v in schema]
    idx_Y = schema.index(schema_Y)
    try:
        X = np.array([[x for idx, x in enumerate(row) if idx in idx_X] for row in data], dtype=np.float64)
    except ValueError:
        print('Values in X and Y must be numbers')

    Y = np.array([data[i][idx_Y] for i in range(len(data))], dtype=object)
    assert len(set(Y) - {None, ''}) == 2, "Y vector should only contain 2 distinct values, or missing values of type " \
                                          "None or ''"
    # Remove rows with missing values
    mask_Y = [y is None or y is '' for y in Y]
    mask_X = np.isnan(X).any(axis=1)
    mask = np.logical_or(mask_X, mask_Y)
    X, Y = X[~mask], Y[~mask]

    # Run algorithm local step
    local_in = X, Y, schema_X, schema_Y
    local_state, local_out = logregr_local_init(local_in=local_in)
    # Save local state
    if not os.path.exists(os.path.dirname(fname_cur_state)):
        try:
            os.makedirs(os.path.dirname(fname_cur_state))
        except OSError as exc:  # Guard against race condition
            if exc.errno != errno.EEXIST:
                raise
    local_state.save(fname=fname_cur_state)
    # Transfer local output (should be the last command)
    local_out.transfer()


if __name__ == '__main__':
    main()
