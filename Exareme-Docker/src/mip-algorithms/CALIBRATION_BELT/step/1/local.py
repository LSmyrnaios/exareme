from __future__ import division
from __future__ import print_function

import sys
from argparse import ArgumentParser
from os import path

import numpy as np
from scipy.special import expit, xlogy

sys.path.append(
        path.dirname(path.dirname(path.dirname(path.dirname(path.abspath(__file__))))) + '/utils/')
sys.path.append(path.dirname(path.dirname(path.dirname(path.dirname(path.abspath(__file__))))) +
                '/CALIBRATION_BELT/')

from algorithm_utils import StateData
from cb_lib import CBIter_Loc2Glob_TD, CBIter_Glob2Loc_TD


def cb_local_iter(local_state, local_in):
    # Unpack local state
    X_matrices, Y, max_deg = local_state['X_matrices'], local_state['Y'], local_state['max_deg']
    # Unpack local input
    coeff_dict = local_in.get_data()

    # Compute 0th, 1st and 2nd derivatives of loglikelihood
    hess_dict = dict()
    grad_dict = dict()
    ll_dict = dict()
    for deg in range(1, max_deg + 1):
        X = X_matrices[deg]
        coeff = coeff_dict[deg]
        # Auxiliary quantities
        z = np.dot(X, coeff)
        s = expit(z)
        d = np.multiply(s, (1 - s))
        D = np.diag(d)
        # Hessian
        hess = np.dot(
                np.transpose(X),
                np.dot(D, X)
        )
        hess_dict[deg] = hess
        # Gradient
        Ymsd = (Y - s) / d  # Stable computation of (Y - s) / d
        Ymsd[(Y == 0) & (s == 0)] = -1
        Ymsd[(Y == 1) & (s == 1)] = 1
        Ymsd = Ymsd.clip(-100, 100)

        grad = np.dot(
                np.transpose(X),
                np.dot(
                        D,
                        z + Ymsd  # np.divide(Y - s, d)
                )
        )
        grad_dict[deg] = grad

        if np.isnan(grad_dict[deg]).any():
            raise ValueError('Grad contains NaNs!', grad_dict[deg], deg, coeff, z, s, d, Y, Ymsd)
        # Log-likelihood
        ll = np.sum(xlogy(Y, s) + xlogy(1 - Y, 1 - s))
        ll_dict[deg] = ll
    # Pack state and results
    local_state = StateData(X_matrices=X_matrices, Y=Y, max_deg=max_deg)
    local_out = CBIter_Loc2Glob_TD(ll_dict, grad_dict, hess_dict)
    return local_state, local_out


def main():
    # Parse arguments
    parser = ArgumentParser()
    parser.add_argument('-cur_state_pkl', required=True,
                        help='Path to the pickle file holding the current state.')
    parser.add_argument('-prev_state_pkl', required=True,
                        help='Path to the pickle file holding the previous state.')
    parser.add_argument('-global_step_db', required=True,
                        help='Path to db holding global step results.')
    args, unknown = parser.parse_known_args()
    # raise ValueError(args)
    fname_cur_state = path.abspath(args.cur_state_pkl)
    fname_prev_state = path.abspath(args.prev_state_pkl)
    global_db = path.abspath(args.global_step_db)

    # Load local state
    local_state = StateData.load(fname_prev_state).data
    # Load global node output
    global_out = CBIter_Glob2Loc_TD.load(global_db)
    # Run algorithm local iteration step
    local_state, local_out = cb_local_iter(local_state=local_state, local_in=global_out)
    # Save local state
    local_state.save(fname=fname_cur_state)
    # Return
    local_out.transfer()


if __name__ == '__main__':
    main()
