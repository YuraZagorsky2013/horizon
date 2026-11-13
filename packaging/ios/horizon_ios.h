#ifndef HORIZON_IOS_H
#define HORIZON_IOS_H

#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

void horizon_start(void);
void horizon_install_setup_ui(void);
bool horizon_setup_ready(void);
void horizon_setup_start(const char *derived_url);
size_t horizon_setup_status(char *buffer, size_t capacity);

#ifdef __cplusplus
}
#endif

#endif
