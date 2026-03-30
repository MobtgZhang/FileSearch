#ifndef PROMPTLOADER_H
#define PROMPTLOADER_H

#include <QString>

class PromptLoader
{
public:
    /** 读取 prompts 目录下文件；失败或文件为空则返回 fallback */
    static QString loadUtf8WithFallback(const QString &fileName, const QString &fallback);

    /** 仅当文件存在且非空时返回内容，否则空串 */
    static QString loadUtf8(const QString &fileName);
};

#endif
