#ifndef WEBFETCHTOOL_H
#define WEBFETCHTOOL_H

#include "IAgentTool.h"

class AppSettings;

class WebFetchTool : public IAgentTool
{
public:
    explicit WebFetchTool(AppSettings *settings = nullptr);

    QString name() const override;
    QString description() const override;
    QVariant execute(const QVariantMap &params) override;

private:
    AppSettings *m_settings = nullptr;
};

#endif
