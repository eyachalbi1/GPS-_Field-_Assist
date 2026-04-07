from fastapi import APIRouter
router = APIRouter()

MOCK_GPS_DEVICES = [
    {
        'SerialNumber': 'GPS001',
        'SIMCardNumber': '8944100030401234567',
        'EquipmentType': 'Tracker Pro',
        'PasswordDevice': '1234'
    },
    {
        'SerialNumber': 'GPS002', 
        'SIMCardNumber': '8944100030401234568',
        'EquipmentType': 'Field Monitor',
        'PasswordDevice': '5678'
    },
]

@router.get('/gps-devices')
async def get_gps_devices():
    return MOCK_GPS_DEVICES

