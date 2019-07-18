import pytest
import json
import requests
import math

endpointUrl = 'http://88.197.53.52:9090/mining/query/PEARSON_CORRELATION'


def get_test_params():
    with open('pearson_runs.json') as json_file:
        params = json.load(json_file)['results']
    params = [(p['input'], p['output']) for p in params]
    return params


@pytest.mark.parametrize("test_input, expected", get_test_params())
def test_eval(test_input, expected):
    headers = {'Content-type': 'application/json', "Accept": "text/plain"}
    res = requests.post(endpointUrl, data=json.dumps(test_input), headers=headers)
    res = json.loads(res.text)
    res = res['result'][0]['data'][0]
    for key, val in expected.items():
        test_val = res[key]
        if type(val) == float:
            assert math.isclose(val, test_val, rel_tol=0, abs_tol=1e-03)
        else:
            assert val == test_val
