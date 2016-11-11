//
//  NBCSource.m
//  NBICreator
//
//  Created by Erik Berglund.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.

#import "NBCSource.h"

#import "NBCDiskImageController.h"
#import "NBCError.h"
#import <sys/sysctl.h>
#import "NBCLog.h"

NSString *const NBCSourceTypeInstallerApplication = @"InstallerApplication";
NSString *const NBCSourceTypeInstallESDDiskImage = @"InstallESDDiskImage";
NSString *const NBCSourceTypeSystemDiskImage = @"SystemDiskImage";
NSString *const NBCSourceTypeSystemDisk = @"SystemDisk";
NSString *const NBCSourceTypeNBI = @"NBI";
NSString *const NBCSourceTypeUnknown = @"Unknown";

@implementation NBCSource

- (id)initWithSourceType:(NSString *)sourceType {
    self = [super init];
    if (self) {
        _sourceType = sourceType;
        NSOperatingSystemVersion version = [[NSProcessInfo processInfo] operatingSystemVersion];
        _bootedVersion = [NSString stringWithFormat:@"%ld.%ld.%ld", version.majorVersion, version.minorVersion, version.patchVersion];
    }
    return self;
}

- (BOOL)detachImage {

    BOOL retval = YES;
    if (_systemVolumeURL != nil) {
        retval = [NBCDiskImageController detachDiskImageAtPath:[_systemVolumeURL path]];
    }
    return retval;
} // detachImage

- (BOOL)unmountImage {

    BOOL retval = YES;
    if ([[_systemVolumeURL path] length] != 0) {
        if ([NBCDiskImageController unmountVolumeAtPath:[_systemVolumeURL path]]) {
            // Unset _imageMountURL…
        } else {
            retval = NO;
        }
    }
    return retval;
} // unmountImage

- (BOOL)detachRecoveryHD {

    BOOL retval = YES;
    if ([[_recoveryVolumeURL path] length] != 0) {
        retval = [NBCDiskImageController detachDiskImageAtPath:[_recoveryVolumeURL path]];
    }
    return retval;
} // detachImage

- (BOOL)unmountRecoveryHD {

    BOOL retval = YES;
    if ([[_recoveryVolumeURL path] length] != 0) {
        retval = [NBCDiskImageController unmountVolumeAtPath:[_recoveryVolumeURL path]];
    }
    return retval;
} // unmountRecoveryHD

- (BOOL)detachBaseSystem {

    BOOL retval = YES;
    if ([_baseSystemDisk isMounted]) {
        retval = [NBCDiskImageController unmountVolumeAtPath:[_baseSystemVolumeURL path]];
    }

    if (retval) {
        retval = [NBCDiskImageController detachDiskImageDevice:_baseSystemVolumeBSDIdentifier];
    }
    return retval;
} // detachBaseSystem

- (BOOL)unmountBaseSystem {
    BOOL retval = YES;
    if ([[_baseSystemVolumeURL path] length] != 0) {
        retval = [NBCDiskImageController unmountVolumeAtPath:[_baseSystemVolumeURL path]];
    }
    return retval;
} // unmountBaseSystem

- (BOOL)detachAll {

    BOOL retval = YES;
    if ([[_baseSystemVolumeURL path] length] != 0) {
        retval = [self unmountBaseSystem];
    }

    if ([[_recoveryVolumeURL path] length] != 0) {
        retval = [self unmountRecoveryHD];
    }

    if ([[_systemVolumeURL path] length] != 0) {
        retval = [self unmountImage];
    }
    return retval;
} // detachAll

- (NSString *)expandVariables:(NSString *)string {

    NSString *newString = string;
    NSString *variableOSVersion = @"%OSVERSION%";
    NSString *variableOSMajorVersion = @"%OSMAJOR%";
    NSString *variableOSMinorVersion = @"%OSMINOR%";
    NSString *variableOSPatchVersion = @"%OSPATCH%";
    NSString *variableOSBuildVersion = @"%OSBUILD%";
    NSString *variableOSIndex = @"%OSINDEX%";
    NSString *variableSourceURL = @"%SOURCEURL%";

    // --------------------------------------------------------------
    //  Expand %OSVERSION%
    // --------------------------------------------------------------
    NSString *osVersion;

    if ([_sourceVersion length] != 0) {
        osVersion = _sourceVersion;
    } else {
        if ([_bootedVersion length] == 0) {
            NSOperatingSystemVersion version = [[NSProcessInfo processInfo] operatingSystemVersion];
            _bootedVersion = [NSString stringWithFormat:@"%ld.%ld.%ld", version.majorVersion, version.minorVersion, version.patchVersion];
        }
        osVersion = _bootedVersion;
    }
    newString = [newString stringByReplacingOccurrencesOfString:variableOSVersion withString:osVersion];

    // --------------------------------------------------------------
    //  Expand %OSMAAJOR%, %OSMINOR%, %OSPATCH%
    // --------------------------------------------------------------
    NSString *osMajorVersion;
    NSString *osMinorVersion;
    NSString *osPatchVersion;
    NSArray *osVersionString = [osVersion componentsSeparatedByString:@"."];
    osMajorVersion = [osVersion componentsSeparatedByString:@"."][0];
    osMinorVersion = [osVersion componentsSeparatedByString:@"."][1];
    if ([osVersionString count] == 3) {
        osPatchVersion = [osVersion componentsSeparatedByString:@"."][2];
    } else {
        osPatchVersion = @"0";
    }

    newString = [newString stringByReplacingOccurrencesOfString:variableOSMajorVersion withString:osMajorVersion];

    newString = [newString stringByReplacingOccurrencesOfString:variableOSMinorVersion withString:osMinorVersion];

    newString = [newString stringByReplacingOccurrencesOfString:variableOSPatchVersion withString:osPatchVersion];

    // --------------------------------------------------------------
    //  Expand %OSBUILD%
    // --------------------------------------------------------------
    NSString *osBuildVersion;
    if ([_sourceBuild length] != 0) {
        osBuildVersion = _sourceBuild;
    } else {
        if ([_bootedBuild length] == 0) {
            int mib[2] = {CTL_KERN, KERN_OSVERSION};
            size_t size = 0;

            // Get the size for the buffer
            sysctl(mib, 2, NULL, &size, NULL, 0);

            char *answer = malloc(size);
            int result = sysctl(mib, 2, answer, &size, NULL, 0);

            if (0 <= result) {
                _bootedBuild = [NSString stringWithCString:answer encoding:NSUTF8StringEncoding];
            }
            free(answer);
        }
        osBuildVersion = _bootedBuild;
    }

    newString = [newString stringByReplacingOccurrencesOfString:variableOSBuildVersion withString:osBuildVersion];

    // --------------------------------------------------------------
    //  Expand %OSINDEX%
    // --------------------------------------------------------------
    NSString *osIndex;
    NSUInteger substringIndex;
    if ([osMinorVersion integerValue] <= 9) {
        substringIndex = (NSUInteger)2;
    } else {
        substringIndex = (NSUInteger)1;
    }
    osIndex = [NSString stringWithFormat:@"%@%@%@", [osMajorVersion substringToIndex:substringIndex], osMinorVersion, osPatchVersion];

    newString = [newString stringByReplacingOccurrencesOfString:variableOSIndex withString:osIndex];

    // --------------------------------------------------------------
    //  Expand %SOURCEURL%
    // --------------------------------------------------------------
    NSString *sourceURL;
    if ([[_systemVolumeURL path] length] != 0) {
        sourceURL = [NSString stringWithFormat:@"%@", [_systemVolumeURL path]];
    } else {
        sourceURL = @"";
    }

    newString = [newString stringByReplacingOccurrencesOfString:variableSourceURL withString:sourceURL];

    return newString;
}

- (NSImage *)productImageForOSVersion:(NSString *)osVersion {

    DDLogDebug(@"[DEBUG] Getting product image for os version: %@", osVersion);

    NSImage *productImage;
    if ([osVersion hasPrefix:@"10.6"]) {
        productImage = [[NSImage alloc] initWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"IconSnowLeopard" withExtension:@"icns"]];
    } else if ([osVersion hasPrefix:@"10.7"]) {
        productImage = [[NSImage alloc] initWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"IconLion" withExtension:@"icns"]];
    } else if ([osVersion hasPrefix:@"10.8"]) {
        productImage = [[NSImage alloc] initWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"IconMountainLion" withExtension:@"icns"]];
    } else if ([osVersion hasPrefix:@"10.9"]) {
        productImage = [[NSImage alloc] initWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"IconMavericks" withExtension:@"icns"]];
    } else if ([osVersion hasPrefix:@"10.10"]) {
        productImage = [[NSImage alloc] initWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"IconYosemite" withExtension:@"icns"]];
    } else if ([osVersion hasPrefix:@"10.11"]) {
        productImage = [[NSImage alloc] initWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"IconElCapitan" withExtension:@"icns"]];
    }
    return productImage;
}

- (void)verifySourceIsMounted {

    DDLogDebug(@"[DEBUG] Source type: %@", _sourceType);

    dispatch_queue_t taskQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(taskQueue, ^{

      NSError *error;

      // --------------------------------------------------------------
      //  Installer Application & InstallESD
      // --------------------------------------------------------------
      if ([self->_sourceType isEqualToString:NBCSourceTypeInstallerApplication] || [self->_sourceType isEqualToString:NBCSourceTypeInstallESDDiskImage]) {
          if ([self->_installESDDisk isMounted]) {
              dispatch_async(dispatch_get_main_queue(), ^{
                if (self->_delegate && [self->_delegate respondsToSelector:@selector(sourceMountSuccessful)]) {
                    [self->_delegate sourceMountSuccessful];
                }
              });
              return;
          }

          if ([self->_installESDDiskImageURL checkResourceIsReachableAndReturnError:&error]) {
              if ([NBCDiskImageController verifyInstallESDDiskImage:self->_installESDDiskImageURL source:self error:&error]) {
                  if ([self->_installESDDisk isMounted]) {
                      dispatch_async(dispatch_get_main_queue(), ^{
                        if (self->_delegate && [self->_delegate respondsToSelector:@selector(sourceMountSuccessful)]) {
                            [self->_delegate sourceMountSuccessful];
                        }
                      });
                      return;
                  } else {
                      error = [NBCError errorWithDescription:@"Unable to mount selected source"];
                      dispatch_async(dispatch_get_main_queue(), ^{
                        if (self->_delegate && [self->_delegate respondsToSelector:@selector(sourceMountFailedWithError:)]) {
                            [self->_delegate sourceMountFailedWithError:error];
                        }
                      });
                      return;
                  }
              } else {
                  dispatch_async(dispatch_get_main_queue(), ^{
                    if (self->_delegate && [self->_delegate respondsToSelector:@selector(sourceMountFailedWithError:)]) {
                        [self->_delegate sourceMountFailedWithError:error];
                    }
                  });
                  return;
              }
          } else {
              dispatch_async(dispatch_get_main_queue(), ^{
                if (self->_delegate && [self->_delegate respondsToSelector:@selector(sourceMountFailedWithError:)]) {
                    [self->_delegate sourceMountFailedWithError:error];
                }
              });
              return;
          }

          // --------------------------------------------------------------
          //  System Disk
          // --------------------------------------------------------------
      } else if ([self->_sourceType isEqualToString:NBCSourceTypeSystemDisk]) {
          if ([self->_systemDisk isMounted]) {
              dispatch_async(dispatch_get_main_queue(), ^{
                if (self->_delegate && [self->_delegate respondsToSelector:@selector(sourceMountSuccessful)]) {
                    [self->_delegate sourceMountSuccessful];
                }
              });
              return;
          } else {
              [self->_systemDisk mount];
              if ([self->_systemDisk isMounted]) {
                  dispatch_async(dispatch_get_main_queue(), ^{
                    if (self->_delegate && [self->_delegate respondsToSelector:@selector(sourceMountSuccessful)]) {
                        [self->_delegate sourceMountSuccessful];
                    }
                  });
                  return;
              } else {
                  error = [NBCError errorWithDescription:@"Unable to mount selected source"];
                  dispatch_async(dispatch_get_main_queue(), ^{
                    if (self->_delegate && [self->_delegate respondsToSelector:@selector(sourceMountFailedWithError:)]) {
                        [self->_delegate sourceMountFailedWithError:error];
                    }
                  });
                  return;
              }
          }

          // --------------------------------------------------------------
          //  System Disk Image
          // --------------------------------------------------------------
      } else if ([self->_sourceType isEqualToString:NBCSourceTypeSystemDiskImage]) {
          if ([self->_systemDisk isMounted]) {
              dispatch_async(dispatch_get_main_queue(), ^{
                if (self->_delegate && [self->_delegate respondsToSelector:@selector(sourceMountSuccessful)]) {
                    [self->_delegate sourceMountSuccessful];
                }
              });
              return;
          } else {
              [self->_systemDisk mount];
              if ([self->_systemDisk isMounted]) {
                  dispatch_async(dispatch_get_main_queue(), ^{
                    if (self->_delegate && [self->_delegate respondsToSelector:@selector(sourceMountSuccessful)]) {
                        [self->_delegate sourceMountSuccessful];
                    }
                  });
                  return;
              }
          }

          if ([self->_systemDiskImageURL checkResourceIsReachableAndReturnError:&error]) {
              if ([NBCDiskImageController verifySystemDiskImage:self->_systemDiskImageURL source:self requireRecoveryPartition:YES error:&error]) {
                  if ([self->_systemDisk isMounted]) {
                      dispatch_async(dispatch_get_main_queue(), ^{
                        if (self->_delegate && [self->_delegate respondsToSelector:@selector(sourceMountSuccessful)]) {
                            [self->_delegate sourceMountSuccessful];
                        }
                      });
                      return;
                  } else {
                      error = [NBCError errorWithDescription:@"Unable to mount selected source"];
                      dispatch_async(dispatch_get_main_queue(), ^{
                        if (self->_delegate && [self->_delegate respondsToSelector:@selector(sourceMountFailedWithError:)]) {
                            [self->_delegate sourceMountFailedWithError:error];
                        }
                      });
                      return;
                  }
              } else {
                  dispatch_async(dispatch_get_main_queue(), ^{
                    if (self->_delegate && [self->_delegate respondsToSelector:@selector(sourceMountFailedWithError:)]) {
                        [self->_delegate sourceMountFailedWithError:error];
                    }
                  });
                  return;
              }
          } else {
              dispatch_async(dispatch_get_main_queue(), ^{
                if (self->_delegate && [self->_delegate respondsToSelector:@selector(sourceMountFailedWithError:)]) {
                    [self->_delegate sourceMountFailedWithError:error];
                }
              });
              return;
          }

          // --------------------------------------------------------------
          //  Unknown Source Type
          // --------------------------------------------------------------
      } else {
          error = [NBCError errorWithDescription:[NSString stringWithFormat:@"Unknown source type: %@", self->_sourceType]];
          dispatch_async(dispatch_get_main_queue(), ^{
            if (self->_delegate && [self->_delegate respondsToSelector:@selector(sourceMountFailedWithError:)]) {
                [self->_delegate sourceMountFailedWithError:error];
            }
          });
          return;
      }
    });
}

- (void)printAllVariables {
    DDLogDebug(@"sourceVersion=%@", _sourceVersion);
    DDLogDebug(@"sourceBuild=%@", _sourceBuild);
    DDLogDebug(@"sourceType=%@", _sourceType);
    DDLogDebug(@"sourceMenuName=%@", _sourceMenuName);
    DDLogDebug(@"installESDDisk=%@", _installESDDisk);
    DDLogDebug(@"installESDDiskImageURL=%@", _installESDDiskImageURL);
    DDLogDebug(@"installESDVolumeURL=%@", _installESDVolumeURL);
    DDLogDebug(@"installESDDiskImageDict=%@", _installESDDiskImageDict);
    DDLogDebug(@"installESDVolumeBSDIdentifier=%@", _installESDVolumeBSDIdentifier);
    DDLogDebug(@"osxInstallerURL=%@", _osxInstallerURL);
    DDLogDebug(@"osxInstallerIconURL=%@", _osxInstallerIconURL);
    DDLogDebug(@"systemDisk=%@", _systemDisk);
    DDLogDebug(@"systemDiskImageURL=%@", _systemDiskImageURL);
    DDLogDebug(@"systemDiskImageDict=%@", _systemDiskImageDict);
    DDLogDebug(@"systemVolumeURL=%@", _systemVolumeURL);
    DDLogDebug(@"systemOSVersion=%@", _systemOSVersion);
    DDLogDebug(@"systemOSBuild=%@", _systemOSBuild);
    DDLogDebug(@"systemVolumeBSDIdentifier=%@", _systemVolumeBSDIdentifier);
    DDLogDebug(@"recoveryDisk=%@", _recoveryDisk);
    DDLogDebug(@"recoveryDiskImageURL=%@", _recoveryDiskImageURL);
    DDLogDebug(@"recoveryDiskImageDict=%@", _recoveryDiskImageDict);
    DDLogDebug(@"recoveryVolumeURL=%@", _recoveryVolumeURL);
    DDLogDebug(@"recoveryVolumeBSDIdentifier=%@", _recoveryVolumeBSDIdentifier);
    DDLogDebug(@"baseSystemDisk=%@", _baseSystemDisk);
    DDLogDebug(@"baseSystemDiskImageURL=%@", _baseSystemDiskImageURL);
    DDLogDebug(@"baseSystemVolumeURL=%@", _baseSystemVolumeURL);
    DDLogDebug(@"baseSystemDiskImageDict=%@", _baseSystemDiskImageDict);
    DDLogDebug(@"baseSystemOSVersion=%@", _baseSystemOSVersion);
    DDLogDebug(@"baseSystemOSBuild=%@", _baseSystemOSBuild);
}

@end
