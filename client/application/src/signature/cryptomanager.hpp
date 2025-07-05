// SPDX-FileCopyrightText: 2022 Open Mobile Platform LLC <community@omp.ru>
// SPDX-License-Identifier: BSD-3-Clause

#ifndef CRYPTOMANAGER_HPP
#define CRYPTOMANAGER_HPP

#include <openssl/pem.h>

class CryptoManager
{
  private:
    static bool checkKeysFolder();
    static bool checkSignatureFolder();
    static bool checkKeys();
    static int generateKeys();
    static int generateKeysFolder();
    static int generateSignatureFolder();
    static bool generateCertificate(EVP_PKEY *private_key);

  public:
    static int initialize();
};

#endif // CRYPTOMANAGER_HPP
