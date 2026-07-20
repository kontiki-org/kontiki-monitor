from boomerang_contracts.alert.catalog import (
    AlertCategoryCatalog,
    AlertConnectorCatalog,
    AlertCriterionDescriptor,
    AlertEventTypeCatalog,
)
from kontiki_host_check.names import HOST_CHECK_SERVICE_NAME

HOST_CATEGORY = "kontiki.host"

_HOST = AlertCriterionDescriptor(
    key="host",
    label="Host",
    operators=["eq", "contains"],
    value_kind="string",
)
_PATH = AlertCriterionDescriptor(
    key="path",
    label="Mount path",
    operators=["eq", "contains"],
    value_kind="string",
)
_SEVERITY = AlertCriterionDescriptor(
    key="severity",
    label="Severity",
    operators=["eq"],
    value_kind="string",
)


def build_alert_subscription_catalog(category=HOST_CATEGORY):
    return AlertConnectorCatalog(
        source_id=HOST_CHECK_SERVICE_NAME,
        categories=[
            AlertCategoryCatalog(
                category=category,
                label="Kontiki Host",
                event_types=[
                    AlertEventTypeCatalog(
                        event_type="disk_space_high",
                        label="Disk occupation high",
                        criteria=[_HOST, _PATH, _SEVERITY],
                    )
                ],
            )
        ],
    )
