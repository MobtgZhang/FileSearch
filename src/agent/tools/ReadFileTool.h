#ifndef READFILETOOL_H
#define READFILETOOL_H

#include "IAgentTool.h"

class ReadFileTool : public IAgentTool
{
public:
    QString name() const override;
    QString description() const override;
    QVariant execute(const QVariantMap &params) override;
};

#endif
