curl -X POST 'https://dev3.hometest.service.nhs.uk/order-router/' \
  -H 'Content-Type: application/fhir+json' \
  -H 'x-correlation-id: 550e8400-e29b-41d4-a716-446655440000' \
  -d '{
    "resourceType": "ServiceRequest",
    "id": "7cb0623e-9cd7-4495-aa66-715c04a81836",
    "status": "active",
    "intent": "order",
    "code": {
        "coding": [
            {
                "system": "http://snomed.info/sct",
                "code": "31676001",
                "display": "HIV antigen test"
            }
        ],
        "text": "HIV antigen test"
    },
    "contained": null,
    "subject": {
        "reference": "#1d6efc98-78e7-4049-9d4f-e651a95d9727",
        "type": null,
        "display": null
    },
    "requester": {
        "reference": "Organization/ORG001",
        "type": null,
        "display": null
    },
    "performer": null,
    "identifier": [
        {
            "value": "PO324822"
        }
    ]
}'
