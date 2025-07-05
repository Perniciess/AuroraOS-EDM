// SPDX-FileCopyrightText: 2022 Open Mobile Platform LLC <community@omp.ru>
// SPDX-License-Identifier: BSD-3-Clause

#ifndef SORTMODEL_HPP
#define SORTMODEL_HPP

#include "filesmodel.hpp"
#include <QSortFilterProxyModel>

class SortModel : public QSortFilterProxyModel
{
    Q_OBJECT
    Q_PROPERTY(
        FilesModel *sourceModel READ sourceModel WRITE setSourceModel NOTIFY sourceModelChanged)
    Q_PROPERTY(
        int sortParameter READ sortParameter WRITE setSortParameter NOTIFY sortParameterChanged)

  public:
    enum SortParameter
    {
        None,
        Date
    };
    Q_ENUM(SortParameter)

    SortModel(QObject *parent = nullptr);
    ~SortModel();

    FilesModel *sourceModel() const;
    int sortParameter() const;
    Q_INVOKABLE bool removeFile(const QString &fileName);

  public slots:
    void setSourceModel(FilesModel *sourceModel);
    void setSortParameter(int sortParameter);

  signals:
    void sourceModelChanged(FilesModel *sourceModel);

    void sortParameterChanged(int sortParameter);

  private:
    int m_sortParameter;
};

#endif // SORTMODEL_HPP
