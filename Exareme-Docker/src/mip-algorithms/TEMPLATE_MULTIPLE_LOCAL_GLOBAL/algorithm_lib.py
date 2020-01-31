# Forward compatibility
from __future__ import division
from __future__ import print_function
from __future__ import unicode_literals

import json

from utils.algorithm_utils import StateData, TransferAndAggregateData, make_json_raw, query_from_formula


def get_data(args):
    args_x = list(
            args.x
                .replace(' ', '')
                .split(',')
    )
    variables = (args_x,)
    # TODO uncomment following if there are both left-hand-side (Y) and right-hand-side (X) expressions
    # args_y = list(
    #         args.y
    #             .replace(' ', '')
    #             .split(',')
    # )
    # variables = (args_y, args_x)
    # TODO add any other algorithm specific data and/or parameters

    # TODO To get data from local DB use this form. If you don't need Y replace it with _
    Y, X = query_from_formula(fname_db=args.input_local_DB,
                              formula=args.formula.replace('_', '~'),  # TODO remove replace once tilda-bug is fixed
                              variables=variables,
                              data_table=args.data_table,
                              metadata_table=args.metadata_table,
                              metadata_code_column=args.metadata_code_column,
                              metadata_isCategorical_column=args.metadata_isCategorical_column,
                              no_intercept=json.loads(args.no_intercept),
                              coding=None if args.coding == 'null' else args.coding)

    # TODO return additionally any other data and/or parameters
    return Y, X


def local_1(local_in):
    # Unpack data TODO add additional data and/or parameters
    Y, X = local_in

    # TODO replace code below with algorithm code
    # -------------------------------------------
    var1, var2 = 1, 2
    # -------------------------------------------

    # Use StateData to save data for use in the SAME node (either local or global)
    # TODO add any other variable you like in the form `var=var`
    local_state = StateData(X=X, Y=Y)

    # Use TransferAndAggregateData to send data to OTHER nodes (local->global or global->local)
    # TODO add any other variable you like in the form `var=(var, AGGREGATION_TYPE) where AGGREGATION_TYPE can be
    #  'add', 'max', 'min' or 'do_nothing'
    local_out = TransferAndAggregateData(var1=(var1, 'add'), var2=(var2, 'add'))

    return local_state, local_out


def global_1(global_in):
    data = global_in.get_data()
    # Unpack data send from local node TODO add any other variable was sent in previous local step
    var1, var2 = data['var1'], data['var2']

    # TODO replace code below with algorithm code
    # -------------------------------------------
    var3 = var1 + var2
    # -------------------------------------------

    # Use StateData to save data for use in the SAME node (either local or global)
    # TODO add any other variable you like in the form `var=var`
    global_state = StateData(var1=var1, var2=var2)

    # Use TransferAndAggregateData to send data to OTHER nodes (local->global or global->local)
    # TODO add any other variable you like in the form `var=(var, AGGREGATION_TYPE) where AGGREGATION_TYPE can be
    #  'add', 'max', 'min' or 'do_nothing'
    global_out = TransferAndAggregateData(var3=(var3, 'do_nothing'))  # AGGREGATION_TYPE is always
    # 'do_nothing' when transferring from global->local

    return global_state, global_out


def local_2(local_state, local_in):
    # Unpack local state TODO add any other variable was saved in previous local step
    X, Y = local_state['X'], local_state['Y']
    # Unpack local input TODO add any other variable was sent in previous global step
    data = local_in.get_data()
    var3 = data['var3']

    # TODO replace code below with algorithm code
    # -------------------------------------------
    var3 = 2 * var3
    # -------------------------------------------

    # Use TransferAndAggregateData to send data to OTHER nodes (local->global or global->local)
    # TODO add any other variable you like in the form `var=(var, AGGREGATION_TYPE) where AGGREGATION_TYPE can be
    #  'add', 'max', 'min' or 'do_nothing'
    local_out = TransferAndAggregateData(var3=(var3, 'add'))

    return local_out


def global_2(global_state, global_in):
    # Unpack global state TODO add any other variable was saved in previous local step
    var1, var2 = global_state['var1'], global_state['var2']
    # Unpack global input
    data = global_in.get_data()
    var3 = data['var3']

    # TODO replace code below with algorithm code
    # -------------------------------------------
    var4 = var1 * var2 * var3
    # -------------------------------------------

    # Pack results into corresponding object
    result = AlgorithmResult(var1, var2, var3, var4)
    output = result.get_output()

    # Print output not allowing nans
    try:
        global_out = json.dumps(output, allow_nan=False)
    except ValueError:
        raise ValueError('Result contains NaNs.')
    return global_out


# TODO Rename and modify this class to pack your algorithm results
class AlgorithmResult(object):
    # Constructor TODO replace with your variables
    def __init__(self, var1, var2, var3, var4):
        self.var1 = var1
        self.var2 = var2
        self.var3 = var3
        self.var4 = var4

    # This method returns a json object with all the algorithm results
    def get_json_raw(self):
        return make_json_raw(var1=self.var1, var2=self.var2, var3=self.var3,
                             var4=self.var4)

    # This method returns a table to be displayed in the frontend. Create as many as you like.
    def get_table(self):
        tabular_data = dict()
        tabular_data["name"] = "My Table"
        tabular_data["profile"] = "tabular-data-resource"
        tabular_data["data"] = [['var1', 'var2', 'var3', 'var4'], [self.var1, self.var2, self.var3, self.var4]]
        tabular_data["schema"] = {
            "fields": [
                {"name": 'var1', "type": "number"},
                {"name": 'var2', "type": "number"},
                {"name": 'var3', "type": "number"},
                {"name": 'var4', "type": "number"},
            ]
        }
        return tabular_data

    # This method packs everything in one json object, to be output in the frontend.
    def get_output(self):
        result = {
            "result": [
                # Raw results
                {
                    "type": "application/json",
                    "data": self.get_json_raw()
                },
                # Tabular data
                {
                    "type": "application/vnd.dataresource+json",
                    "data": self.get_table()
                }
            ]
        }
        return result
