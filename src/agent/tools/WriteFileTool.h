#ifndef WRITEFILETOOL_H
#define WRITEFILETOOL_H

#include "IAgentTool.h"

class WriteFileTool : public IAgentTool
{
public:
    QString name() const override;
    QString description() const override;
    QVariant execute(const QVariantMap &params) override;
};

#endif
