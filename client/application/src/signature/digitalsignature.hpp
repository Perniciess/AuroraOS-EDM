// SPDX-FileCopyrightText: 2022 Open Mobile Platform LLC <community@omp.ru>
// SPDX-License-Identifier: BSD-3-Clause

#ifndef DIGITALSIGNATURE_HPP
#define DIGITALSIGNATURE_HPP

#include <QObject>
#include <vector>

class DigitalSignature : public QObject
{
    Q_OBJECT
  public:
    explicit DigitalSignature(QObject *parent = nullptr);
    virtual ~DigitalSignature();

    std::vector<unsigned char> calculateSHA256(const QString &filePath);

    Q_INVOKABLE bool signFile(const QString &fileName);

  private:
    bool signHash(const std::vector<unsigned char> &hash, const QString &outputFile);
};

#endif // DIGITALSIGNATURE_HPP
