from boomerang_contracts.alert.catalog import (
    AlertCategoryCatalog,
    AlertConnectorCatalog,
    AlertCriterionDescriptor,
    AlertEventTypeCatalog,
)

from kontiki_monitor.names import KONTIKI_MONITOR_SERVICE_NAME

REGISTRY_CATEGORY = "kontiki.registry"

_SERVICE_NAME = AlertCriterionDescriptor(
    key="service_name",
    label="Service name",
    operators=["eq", "contains"],
    value_kind="string",
)
_HOST = AlertCriterionDescriptor(
    key="host",
    label="Host",
    operators=["eq", "contains"],
    value_kind="string",
)
_VERSION = AlertCriterionDescriptor(
    key="version",
    label="Version",
    operators=["eq", "contains"],
    value_kind="string",
)
_PREVIOUS_STATE = AlertCriterionDescriptor(
    key="previous_state",
    label="Previous state",
    operators=["eq"],
    value_kind="string",
)
_NEW_STATE = AlertCriterionDescriptor(
    key="new_state",
    label="New state",
    operators=["eq"],
    value_kind="string",
)
_REASON = AlertCriterionDescriptor(
    key="reason",
    label="Reason",
    operators=["eq", "contains"],
    value_kind="string",
)
_EXCEPTION_TYPE = AlertCriterionDescriptor(
    key="exception_type",
    label="Exception type",
    operators=["eq", "contains"],
    value_kind="string",
)


def build_alert_subscription_catalog(
    category: str = REGISTRY_CATEGORY,
) -> AlertConnectorCatalog:
    return AlertConnectorCatalog(
        source_id=KONTIKI_MONITOR_SERVICE_NAME,
        categories=[
            AlertCategoryCatalog(
                category=category,
                label="Kontiki Registry",
                event_types=[
                    AlertEventTypeCatalog(
                        event_type="instance_registered",
                        label="Instance registered",
                        criteria=[_SERVICE_NAME, _HOST, _VERSION],
                    ),
                    AlertEventTypeCatalog(
                        event_type="instance_unregistered",
                        label="Instance unregistered",
                        criteria=[_SERVICE_NAME],
                    ),
                    AlertEventTypeCatalog(
                        event_type="instance_state_changed",
                        label="Instance state changed",
                        criteria=[_SERVICE_NAME, _PREVIOUS_STATE, _NEW_STATE, _REASON],
                    ),
                    AlertEventTypeCatalog(
                        event_type="exception_recorded",
                        label="Exception recorded",
                        criteria=[_SERVICE_NAME, _EXCEPTION_TYPE],
                    ),
                    AlertEventTypeCatalog(
                        event_type="expected_service_missing",
                        label="Expected service missing",
                        criteria=[_SERVICE_NAME],
                    ),
                    AlertEventTypeCatalog(
                        event_type="insufficient_active_instances",
                        label="Insufficient active instances",
                        criteria=[_SERVICE_NAME],
                    ),
                ],
            )
        ],
    )
