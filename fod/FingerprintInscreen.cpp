/*
 * Copyright (C) 2019 The LineageOS Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#define LOG_TAG "FingerprintInscreenService"

#include "FingerprintInscreen.h"
#include <hidl/HidlTransportSupport.h>
#include <android-base/logging.h>
#include <fstream>
#include <cmath>
#include <thread>

/* Hardcoded stuffs */
#define PRESSED "/sys/kernel/oppo_display/notify_fppress"
#define NOTIFY_BLANK_PATH "/sys/kernel/oppo_display/notify_panel_blank"
#define AOD_MODE_PATH "/sys/kernel/oppo_display/aod_light_mode_set"
#define DOZE_STATUS "/proc/touchpanel/DOZE_STATUS"
#define DIMLAYER "/sys/kernel/oppo_display/dimlayer_hbm"
#define X 445
#define Y 1988
#define SIZE 190
#define ON 1
#define OFF 0

namespace {

template <typename T>
static inline void set(const std::string& path, const T& value) {
    std::ofstream file(path);
    file << value;
    //LOG(INFO) << "wrote path: " << path << ", value: " << value << "\n";
}

template <typename T>
static inline T get(const std::string& path, const T& def) {
    std::ifstream file(path);
    T result;

    file >> result;
    return file.fail() ? def : result;
}

} // anonymous namespace

namespace vendor {
namespace lineage {
namespace biometrics {
namespace fingerprint {
namespace inscreen {
namespace V1_0 {
namespace implementation {

FingerprintInscreen::FingerprintInscreen():mFingerPressed{false} {
}

Return<int32_t> FingerprintInscreen::getPositionX() {
    return X;
}

Return<int32_t> FingerprintInscreen::getPositionY() {
    return Y;
}

Return<int32_t> FingerprintInscreen::getSize() {
    return SIZE;
}

Return<void> FingerprintInscreen::onStartEnroll() {
    return Void();
}

Return<void> FingerprintInscreen::onFinishEnroll() {
    return Void();
}

Return<void> FingerprintInscreen::onPress() {
    mFingerPressed = true;
    set(DIMLAYER, ON);
    std::thread([this]() {
        std::this_thread::sleep_for(std::chrono::milliseconds(39));
        if (mFingerPressed) {
            set(PRESSED, ON);
        }
    }).detach();
    return Void();
}

Return<void> FingerprintInscreen::onRelease() {
    mFingerPressed = false;
    set(PRESSED, OFF);
    set(DIMLAYER, OFF);
    return Void();
}

Return<void> FingerprintInscreen::onShowFODView() {
    if(get(DOZE_STATUS, OFF)) {
    set(NOTIFY_BLANK_PATH, ON);
    set(AOD_MODE_PATH, ON);
    }
    return Void();
}

Return<void> FingerprintInscreen::onHideFODView() {
    return Void();
}

Return<bool> FingerprintInscreen::handleAcquired(int32_t /* acquiredInfo */, int32_t /* vendorCode */) {
    return false;
}

Return<bool> FingerprintInscreen::handleError(int32_t /* error */, int32_t /* vendorCode */) {
    return false;
}

Return<void> FingerprintInscreen::setLongPressEnabled(bool) {
    return Void();
}

Return<int32_t> FingerprintInscreen::getDimAmount(int32_t /* brightness */) {
    return 0; 
}

Return<bool> FingerprintInscreen::shouldBoostBrightness() {
    return false;
}

Return<void> FingerprintInscreen::setCallback(const sp<::vendor::lineage::biometrics::fingerprint::inscreen::V1_0::IFingerprintInscreenCallback>& callback) {
    {
        std::lock_guard<std::mutex> _lock(mCallbackLock);
        mCallback = callback;
    }
    return Void();
}

}  // namespace implementation
}  // namespace V1_0
}  // namespace inscreen
}  // namespace fingerprint
}  // namespace biometrics
}  // namespace lineage
}  // namespace vendor
