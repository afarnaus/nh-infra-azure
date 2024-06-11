import azure.functions as func
from azure.identity import DefaultAzureCredential
import logging
import json
import msal
import requests
import boto3
import json
import time

def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Python HTTP trigger function processed a request.')

    name = req.params.get('name')
    if not name:
        try:
            req_body = req.get_json()
        except ValueError:
            pass
        else:
            name = req_body.get('name')

    #Set res as response
    response = func.HttpResponse(
        "This HTTP triggered function executed successfully. Pass a name in the query string or in the request body for a personalized response.",
        status_code=200
    )
    
    if name:
        response = func.HttpResponse(f"Hello, {name}. This HTTP triggered function executed successfully.")

    return response



from botocore.exceptions import ClientError

def lambda_handler(event, context):
    session = boto3.session.Session()
    client = session.client(
        service_name='secretsmanager',
        region_name="us-east-1"
    )
    secrets_raw = get_secret(client, "nms-sandbox-secrets")
    secrets = json.loads(secrets_raw)

    azure_client_id = secrets['AZURE_CLIENT_ID']
    azure_secret = secrets['AZURE_SECRET']
    azure_authority = secrets['AZURE_AUTHORITY']
    dynamics_base_url = secrets['DYNAMICS_BASE_URL']
    neon_api_header = secrets['NEON_API_HEADER']
    neon_base_url = secrets['NEON_BASE_URL']
    
    accounts = get_all_accounts(neon_base_url, neon_api_header)
    neon_accounts = accounts['accounts']
    contacts = create_contact_list(neon_accounts)
    token = setupMASL(azure_client_id, azure_secret, azure_authority, dynamics_base_url)
    existing_contacts = create_current_dynamics_neon_list(dynamics_base_url, token)


    for contact in contacts:
        if contact['cr5a5_neoncrmaccountid'] not in existing_contacts:
            print("-----------------------------------------------------")
            api_url = f'{dynamics_base_url}/api/data/v9.2/contacts'
            body = json.dumps(contact)
            response = makeDynamicsAPIPOSTRequest(api_url, token, body)
            print("Response: ", response.json())
            print("-----------------------------------------------------")



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


def get_secret(client, secret_name):
    try:
        get_secret_value_response = client.get_secret_value(
            SecretId=secret_name
        )
    except ClientError as e:
        raise e

    secret = get_secret_value_response['SecretString']
    
    return secret

def setupMASL(azure_client_id, azure_secret, azure_authority, dynamics_base_url):
    app = msal.ConfidentialClientApplication(
        client_id=azure_client_id,
        client_credential=azure_secret,
        authority=azure_authority
    )
    result = app.acquire_token_for_client(scopes=[f"{dynamics_base_url}/.default"])
    
    if 'access_token' in result:
         access_token = result['access_token']
         return access_token
    else:
        print("Could not obtain access token, retrying in 10 seconds")
        time.sleep(10)
        result = app.acquire_token_for_client(scopes=[f"{dynamics_base_url}/.default"])
