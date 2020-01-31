# Forward compatibility
from __future__ import division
from __future__ import print_function
from __future__ import unicode_literals

from os import path

from TEMPLATE_MULTIPLE_LOCAL_GLOBAL.algorithm_lib import get_data, local_1
from utils.algorithm_utils import parse_exareme_args


def main(args):
    fname_cur_state = path.abspath(args.cur_state_pkl)

    local_in = get_data(args)
    # Run algorithm local step
    local_state, local_out = local_1(local_in=local_in)
    # Save local state
    local_state.save(fname=fname_cur_state)
    # Transfer local output
    local_out.transfer()


if __name__ == '__main__':
    args = parse_exareme_args(__file__)
    main(args)
