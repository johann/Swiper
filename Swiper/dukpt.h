#import <CommonCrypto/CommonCryptor.h>

void dukptDeriveIPEK(uint8_t bdk[16], uint8_t ksn[10], uint8_t ipek[16]);
void dukptCalculateDataKey(uint8_t ksn[10], uint8_t ipek[16], uint8_t dukptDataKey[16]);
void dukptCalculatePINKey(uint8_t ksn[10], uint8_t ipek[16], uint8_t dukptPINKey[16]);
int trides_crypto(int operation, int mode, void *data, int length, void *result, void *key);
