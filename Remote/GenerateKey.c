//
// Copyright © 2023 osy. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#include "GenerateKey.h"
#include <stdio.h>
#include <openssl/bio.h>
#include <openssl/conf.h>
#include <openssl/err.h>
#include <openssl/objects.h>
#include <openssl/pem.h>
#include <openssl/pkcs12.h>
#include <openssl/x509v3.h>

#define X509_ENTRY_MAX_LENGTH (1024)

/* Add extension using V3 code: we can set the config file as NULL
 * because we wont reference any other sections.
 */
static int add_ext(X509 *cert, int nid, char *value) {
    X509_EXTENSION *ex;
    X509V3_CTX ctx;
    /* This sets the 'context' of the extensions. */
    /* No configuration database */
    X509V3_set_ctx_nodb(&ctx);
    /* Issuer and subject certs: both the target since it is self signed,
     * no request and no CRL
     */
    X509V3_set_ctx(&ctx, cert, cert, NULL, NULL, 0);
    ex = X509V3_EXT_conf_nid(NULL, &ctx, nid, value);
    if (!ex) {
        return 0;
    }

    X509_add_ext(cert, ex, -1);
    X509_EXTENSION_free(ex);
    return 1;
}

static int mkrsacert(X509 **x509p, EVP_PKEY **pkeyp, const char *commonName, const char *organizationName, long serial, int days, int isClient) {
    X509 *x = NULL;
    EVP_PKEY *pk = NULL;
    BIGNUM *bne = NULL;
    RSA *rsa = NULL;
    X509_NAME *name = NULL;

    if ((pk = EVP_PKEY_new()) == NULL) {
        goto err;
    }

    if ((x = X509_new()) == NULL) {
        goto err;
    }

    bne = BN_new();
    if (!bne || !BN_set_word(bne, RSA_F4)){
        goto err;
    }

    rsa = RSA_new();
    if (!rsa || !RSA_generate_key_ex(rsa, 4096, bne, NULL)) {
        goto err;
    }
    BN_free(bne);
    bne = NULL;
    if (!EVP_PKEY_assign_RSA(pk, rsa)) {
        goto err;
    }
    rsa = NULL; // EVP_PKEY_assign_RSA takes ownership

    X509_set_version(x, 2);
    ASN1_INTEGER_set(X509_get_serialNumber(x), serial);
    X509_gmtime_adj(X509_get_notBefore(x), 0);
    X509_gmtime_adj(X509_get_notAfter(x), (long)60*60*24*days);
    X509_set_pubkey(x, pk);

    name = X509_get_subject_name(x);

    /* This function creates and adds the entry, working out the
     * correct string type and performing checks on its length.
     * Normally we'd check the return value for errors...
     */
    X509_NAME_add_entry_by_txt(name, SN_commonName,
                MBSTRING_UTF8, (const unsigned char *)commonName, -1, -1, 0);
    X509_NAME_add_entry_by_txt(name, SN_organizationName,
                MBSTRING_UTF8, (const unsigned char *)organizationName, -1, -1, 0);

    /* Its self signed so set the issuer name to be the same as the
      * subject.
     */
    X509_set_issuer_name(x, name);

    /* Add various extensions: standard extensions */
    add_ext(x, NID_basic_constraints, "critical,CA:TRUE");
    add_ext(x, NID_key_usage, "critical,keyCertSign,cRLSign,keyEncipherment,digitalSignature");
    if (isClient) {
        add_ext(x, NID_ext_key_usage, "clientAuth");
    } else {
        add_ext(x, NID_ext_key_usage, "serverAuth");
    }
    add_ext(x, NID_subject_key_identifier, "hash");

    if (!X509_sign(x, pk, EVP_sha256())) {
        goto err;
    }

    *x509p = x;
    *pkeyp = pk;
    return 1;
err:
    if (pk) {
        EVP_PKEY_free(pk);
    }
    if (x) {
        X509_free(x);
    }
    if (bne) {
        BN_free(bne);
    }
    return 0;
}

static _Nullable CFDataRef CreateP12FromKey(EVP_PKEY *pkey, X509 *cert) {
    PKCS12 *p12;
    BIO *mem;
    char *ptr;
    long length;
    CFDataRef data;

    p12 = PKCS12_create("password", NULL, pkey, cert, NULL, NID_pbe_WithSHA1And3_Key_TripleDES_CBC, NID_pbe_WithSHA1And40BitRC2_CBC, PKCS12_DEFAULT_ITER, 1, 0);
    if (!p12) {
        ERR_print_errors_fp(stderr);
        return NULL;
    }
    mem = BIO_new(BIO_s_mem());
    if (!mem || !i2d_PKCS12_bio(mem, p12)) {
        ERR_print_errors_fp(stderr);
        PKCS12_free(p12);
        BIO_free(mem);
        return NULL;
    }
    PKCS12_free(p12);
    length = BIO_get_mem_data(mem, &ptr);
    data = CFDataCreate(kCFAllocatorDefault, (void *)ptr, length);
    BIO_free(mem);
    return data;
}

static _Nullable CFDataRef CreatePrivatePEMFromKey(EVP_PKEY *pkey) {
    BIO *mem;
    char *ptr;
    long length;
    CFDataRef data;

    mem = BIO_new(BIO_s_mem());
    if (!mem || !PEM_write_bio_PrivateKey(mem, pkey, NULL, NULL, 0, NULL, NULL)) {
        ERR_print_errors_fp(stderr);
        BIO_free(mem);
        return NULL;
    }
    length = BIO_get_mem_data(mem, &ptr);
    data = CFDataCreate(kCFAllocatorDefault, (void *)ptr, length);
    BIO_free(mem);
    return data;
}

static _Nullable CFDataRef CreatePublicPEMFromCert(X509 *cert) {
    BIO *mem;
    char *ptr;
    long length;
    CFDataRef data;

    mem = BIO_new(BIO_s_mem());
    if (!mem || !PEM_write_bio_X509(mem, cert)) {
        ERR_print_errors_fp(stderr);
        BIO_free(mem);
        return NULL;
    }
    length = BIO_get_mem_data(mem, &ptr);
    data = CFDataCreate(kCFAllocatorDefault, (void *)ptr, length);
    BIO_free(mem);
    return data;
}

static _Nullable CFDataRef CreatePublicKeyFromCert(X509 *cert) {
    EVP_PKEY* pubkey;
    BIO *mem;
    char *ptr;
    long length;
    CFDataRef data;

    pubkey = X509_get_pubkey(cert);
    if (!pubkey) {
        ERR_print_errors_fp(stderr);
        return NULL;
    }
    mem = BIO_new(BIO_s_mem());
    if (!mem || !i2d_PUBKEY_bio(mem, pubkey)) {
        ERR_print_errors_fp(stderr);
        EVP_PKEY_free(pubkey);
        BIO_free(mem);
        return NULL;
    }
    length = BIO_get_mem_data(mem, &ptr);
    data = CFDataCreate(kCFAllocatorDefault, (void *)ptr, length);
    BIO_free(mem);
    EVP_PKEY_free(pubkey);
    return data;
}

_Nullable CFArrayRef GenerateRSACertificate(CFStringRef _Nonnull commonName, CFStringRef _Nonnull organizationName, CFNumberRef _Nullable serial, CFNumberRef _Nullable days, CFBooleanRef _Nonnull isClient) {
    char _commonName[X509_ENTRY_MAX_LENGTH];
    char _organizationName[X509_ENTRY_MAX_LENGTH];
    long _serial = 0;
    int _days = 365;
    int _isClient = 0;
    X509 *cert;
    EVP_PKEY *pkey;
    CFDataRef arr[4] = {NULL};
    CFArrayRef cfarr = NULL;

    if (!CFStringGetCString(commonName, _commonName, X509_ENTRY_MAX_LENGTH, kCFStringEncodingUTF8)) {
        return NULL;
    }
    if (!CFStringGetCString(organizationName, _organizationName, X509_ENTRY_MAX_LENGTH, kCFStringEncodingUTF8)) {
        return NULL;
    }
    if (serial) {
        CFNumberGetValue(serial, kCFNumberLongType, &_serial);
    }
    if (days) {
        CFNumberGetValue(days, kCFNumberIntType, &_days);
    }
    _isClient = CFBooleanGetValue(isClient);

    OpenSSL_add_all_algorithms();
    ERR_load_crypto_strings();
    if (!mkrsacert(&cert, &pkey, _commonName, _organizationName, _serial, _days, _isClient)) {
        ERR_print_errors_fp(stderr);
        return NULL;
    }
    arr[0] = CreateP12FromKey(pkey, cert);
    arr[1] = CreatePrivatePEMFromKey(pkey);
    arr[2] = CreatePublicPEMFromCert(cert);
    arr[3] = CreatePublicKeyFromCert(cert);
    if (arr[0] && arr[1] && arr[2] && arr[3]) {
        cfarr = CFArrayCreate(kCFAllocatorDefault, (const void **)arr, 4, &kCFTypeArrayCallBacks);
    }
    if (arr[0]) {
        CFRelease(arr[0]);
    }
    if (arr[1]) {
        CFRelease(arr[1]);
    }
    if (arr[2]) {
        CFRelease(arr[2]);
    }
    if (arr[3]) {
        CFRelease(arr[3]);
    }
    EVP_PKEY_free(pkey);
    X509_free(cert);
    return cfarr;
}
