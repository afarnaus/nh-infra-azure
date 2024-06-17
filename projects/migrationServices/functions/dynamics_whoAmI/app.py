import azure.functions as func
from azure.identity import DefaultAzureCredential
import logging
import json
import msal
import requests
import json
from azure.keyvault.secrets import SecretClient

credential = DefaultAzureCredential()
dynamics_base_url = "https://org3adf6fbc.crm.dynamics.com/"


def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Python HTTP trigger function processed a request.')

    # Get the token
    result = setup_msal()
    if 'access_token' in result:
        # Use the access token to call Dynamics 365 Web API
        access_token = result['access_token']
        api_url = f'{dynamics_base_url}api/data/v9.2/WhoAmI'
        headers = {'Authorization': f'Bearer {access_token}', 'Accept': 'application/json', 'OData-MaxVersion': '4.0', 'OData-Version': '4.0'}
        
        # Make a GET request to the Dynamics 365 Web API
        response = requests.get(api_url, headers=headers)
        
        if response.status_code == 200:
            print(response.json())
        else:
            print(f'API Request Error: {response.status_code}')
    else:
        print('Could not obtain access token')

    return func.HttpResponse(json.dumps(response), status_code=200)



def setup_msal():
    azure_client_id = get_akv_secret("azure-reg-client-id")
    azure_secret = get_akv_secret("azure-reg-secret")
    azure_authority = get_akv_secret("azure-authority")

    app = msal.ConfidentialClientApplication(
        client_id=azure_client_id,
        client_credential=azure_secret,
        authority=azure_authority
    )

    result = app.acquire_token_for_client(scopes=[f"{dynamics_base_url}.default"])

    return result

def get_akv_secret(secret_name):
    vault_name = "nh-tf-managed-kv"
    kv_url = f"https://{vault_name}.vault.azure.net/"
    try:
        client = SecretClient(vault_url=kv_url, credential=credential)
        secret = client.get_secret(secret_name)
        return secret.value
    except Exception as e:
        return str(e)

