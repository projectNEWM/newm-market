import json


def byte_struc(string: str) -> dict:
    return {
        "bytes": string
    }


def list_struc(list_of_token_struc: list[any]) -> dict:
    return {
        "list": list_of_token_struc
    }


def token_struc(pid: str, tkn: str, amt: int) -> dict:
    return {
        "constructor": 0,
        "fields": [
            {
                "bytes": pid
            },
            {
                "bytes": tkn
            },
            {
                "int": amt
            }
        ]
    }


def tokens_struc(list_of_token_struc: list) -> dict:
    return {
        "constructor": 0,
        "fields": [list_struc(list_of_token_struc)]
    }


def get_token_data(file_path: str) -> dict:
    with open(file_path, 'r') as file:
        data = json.load(file)
    return data


def create_token_string(list_of_token_struc: list) -> str:
    string = ""
    for t in list_of_token_struc:
        token = f"{t['fields'][2]['int']} {t['fields'][0]['bytes']}.{t['fields'][1]['bytes']}"
        if string == "":
            string += token
        else:
            string += " + " + token
    return string


def build_token_list(file_path):
    data = get_token_data(file_path)
    list_of_token_struc = []
    for utxo in data:
        value = data[utxo]['value']
        for pid in value:
            if pid != 'lovelace':
                for tkn in value[pid]:
                    amt = value[pid][tkn]
                    token = token_struc(pid, tkn, amt)
                    list_of_token_struc.append(token)
    return list_of_token_struc


if __name__ == "__main__":
    file_path = "../tmp/current_band_lock_utxo.json"
    data = get_token_data(file_path)
    list_of_token_struc = build_token_list(file_path)
    assets = create_token_string(list_of_token_struc)
    print(assets)

    prefixes = []
    for t in list_of_token_struc:
        tkn = f"{t['fields'][1]['bytes']}"
        prefixes.append(byte_struc(tkn[0:8]))
    print(prefixes)
    print(len(prefixes))
