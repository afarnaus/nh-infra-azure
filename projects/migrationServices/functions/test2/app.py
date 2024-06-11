import azure.functions as func
import logging
import json

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

    