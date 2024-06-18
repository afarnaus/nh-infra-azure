import azure.functions as func
from azure.identity import DefaultAzureCredential
import logging
import json
import msal
import requests
import json
from azure.keyvault.secrets import SecretClient

def main(req: func.TimerRequest) -> None:
    try:
        logging.info('Python HTTP trigger function processed a request.')
        credential = DefaultAzureCredential()
        dynamics_base_url = "https://org3adf6fbc.crm.dynamics.com/"
        neon_base_url = get_akv_secret(credential, "neon-api-url")
        neon_api_header = get_akv_secret(credential, "neon-api-auth-header")
        accounts = get_all_accounts(neon_base_url, neon_api_header)
        neon_accounts = accounts['accounts']
        contacts = create_contact_list(neon_accounts)
        token = setup_msal(credential, dynamics_base_url)['access_token']
        existing_contacts = create_current_dynamics_neon_list(dynamics_base_url, token)

        for contact in contacts:
            if contact['cr5a5_neoncrmaccountid'] not in existing_contacts:
                print("-----------------------------------------------------")
                api_url = f'{dynamics_base_url}/api/data/v9.2/contacts'
                body = json.dumps(contact)
                response = makeDynamicsAPIPOSTRequest(api_url, token, body)
                print(f"Contact {contact['firstname']} {contact['lastname']} created successfully")
                print("-----------------------------------------------------")

    except Exception as e:
        logging.info(f'Error: {e}')
        response = {'error': str(e)}
    
    return func.HttpResponse(json.dumps(response), status_code=200)

def makeDynamicsAPIGETRequest(api_url, access_token):
    headers = {
        'Authorization': f'Bearer {access_token}',
        'Accept': 'application/json',
        'OData-MaxVersion': '4.0',
        'OData-Version': '4.0'
    }
    response = requests.get(api_url, headers=headers)
    return response

def makeDynamicsAPIPOSTRequest(api_url, access_token, body):
    headers = {
        'Authorization': f'Bearer {access_token}',
        'Accept': 'application/json',
        'OData-MaxVersion': '4.0',
        'OData-Version': '4.0',
        'Prefer': 'return=representation',
        'Content-Type': 'application/json'
    }
    response = requests.post(api_url, headers=headers, data=body)
    return response

def create_contact_list(neon_accounts):
    contacts = []
    for account in neon_accounts:
        firstname = account['firstName']
        lastname = account['lastName']
        email = account['email']

        ## IF firstname, lastname, or email (any) is None, skip this account
        if (lastname == "" or lastname is None) or (email == "" or email is None):
            continue
        else:
            contact = {
                    "cr5a5_neoncrmaccountid": int(account['accountId']),
                    "lastname": account['lastName'],
                    "firstname": account['firstName'],
                    "cr5a5_companyname": account['companyName'],
                    "emailaddress1": account['email'],
                    "cr5a5_neoncrmaccounttype": account['userType']
            }
            contacts.append(contact)

    return contacts


def create_current_dynamics_neon_list(api_url, token):
    function_url = f'{api_url}/api/data/v9.2/contacts?$select=cr5a5_neoncrmaccountid'
    result = makeDynamicsAPIGETRequest(function_url, token)
    ids = []

    if result.status_code == 200:
        data = result.json()
        for contact in data['value']:
            ids.append(contact['cr5a5_neoncrmaccountid'])
        return ids
    else:
        print(f'API Request Error: {result.status_code}')
        return None


def fetch_data(page, neon_base_url, neon_api_header):
    url = f"{neon_base_url}/accounts"
    headers = {
        "Authorization": neon_api_header,
    }
    params = {
        "userType": "INDIVIDUAL",
        "currentPage": page,
    }
    response = requests.get(url, headers=headers, params=params)
    if response.status_code == 200:
        return response.json()
    else:
        return None
    
def get_all_accounts(neon_base_url, neon_api_header):
    initial_data = fetch_data(0, neon_base_url, neon_api_header)
    total_pages = initial_data['pagination']['totalPages']
    all_accounts = initial_data['accounts']
    for page in range(1, total_pages):
        data = fetch_data(page, neon_base_url, neon_api_header)
        all_accounts.extend(data['accounts'])
    return {"accounts": all_accounts}

def setup_msal(credential, dynamics_base_url):
    try:
        azure_client_id = get_akv_secret(credential, "azure-reg-client-id")
        azure_secret = get_akv_secret(credential, "azure-reg-secret")
        azure_authority = get_akv_secret(credential, "azure-authority")

        app = msal.ConfidentialClientApplication(
            client_id=azure_client_id,
            client_credential=azure_secret,
            authority=azure_authority
        )
        #Get Dynamics Token
        result = app.acquire_token_for_client(scopes=[f"{dynamics_base_url}.default"])
    except Exception as e:
        result = str(e)

    return result

def get_akv_secret(credential, secret_name):
    vault_name = "nh-tf-managed-kv"
    kv_url = f"https://{vault_name}.vault.azure.net/"
    try:
        client = SecretClient(vault_url=kv_url, credential=credential)
        secret = client.get_secret(secret_name)
        return secret.value
    except Exception as e:
        return str(e)

