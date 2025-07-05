// SPDX-FileCopyrightText: 2022 Open Mobile Platform LLC <community@omp.ru>
// SPDX-License-Identifier: BSD-3-Clause

#ifndef CONFIG_HPP
#define CONFIG_HPP

#include <auroraapp.h>
#include <filesystem>

namespace fs = std::filesystem;

class Config
{
  public:
    static const fs::path &keysFolder();
    static const fs::path &signatureFolder();
    static const fs::path &privateKey();
    static const fs::path &publicKey();
    static const fs::path &certificate();
    static const fs::path &databaseFolder();
    static const fs::path &databaseFile();

  private:
    static const fs::path &basePath();
};
#endif // CONFIG_HPP
