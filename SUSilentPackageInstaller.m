//
//  SUSilentPackageInstaller.m
//  Sparkle
//
//  Created by Ricardo on 2/7/13.
//
//

#import "SUSilentPackageInstaller.h"
#import <Cocoa/Cocoa.h>
#import "SUConstants.h"
#import "SULog.h"

NSString *SUSilentPackageInstallerHostKey = @"SUSilentPackageInstallerHost";
NSString *SUSilentPackageInstallerDelegateKey = @"SUSilentPackageInstallerDelegate";
NSString *SUSilentPackageInstallerInstallationPathKey = @"SUSilentPackageInstallerInstallationPathKey";
NSString *SUSilentPackageInstallerScriptKey = @"SUSilentPackageInstallerScript";

@implementation SUSilentPackageInstaller

+ (void)finishInstallationWithInfo:(NSDictionary *)info
{
	[self finishInstallationToPath:[info objectForKey:SUSilentPackageInstallerInstallationPathKey] withResult:YES host:[info objectForKey:SUSilentPackageInstallerHostKey] error:nil delegate:[info objectForKey:SUSilentPackageInstallerDelegateKey]];
}

+ (void)performInstallationWithInfo:(NSDictionary *)info
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	NSAppleScript *installerScript = [[NSAppleScript alloc] initWithSource:[info objectForKey:SUSilentPackageInstallerScriptKey]];
	NSDictionary *installerError;
	NSAppleEventDescriptor *returnDescriptor = [installerScript executeAndReturnError:&installerError];

	if (returnDescriptor.descriptorType) {
		// Known bug: if the installation fails or is canceled, Sparkle goes ahead and restarts, thinking everything is fine.
		[self performSelectorOnMainThread:@selector(finishInstallationWithInfo:) withObject:info waitUntilDone:NO];
	} else {
		SULog(@"Error running AppleScript update command: %@", [installerError objectForKey:@"NSAppleScriptErrorMessage"]);
		NSError *error = [NSError errorWithDomain:SUSparkleErrorDomain code:SUInstallationError userInfo:[NSDictionary dictionaryWithObject:SULocalizedString(@"An error occurred while installing the update. Please try again later.", nil) forKey:NSLocalizedDescriptionKey]];
		[self finishInstallationToPath:[info objectForKey:SUSilentPackageInstallerInstallationPathKey] withResult:NO host:[info objectForKey:SUSilentPackageInstallerHostKey] error:error delegate:[info objectForKey:SUSilentPackageInstallerDelegateKey]];
	}

	[pool drain];
}

+ (void)performInstallationToPath:(NSString *)installationPath fromPath:(NSString *)path host:(SUHost *)host delegate:delegate synchronously:(BOOL)synchronously versionComparator:(id <SUVersionComparison>)comparator
{
	if (![[NSFileManager defaultManager] fileExistsAtPath:@"/usr/sbin/installer"]) {
		NSError *error = [NSError errorWithDomain:SUSparkleErrorDomain code:SUMissingInstallerToolError userInfo:[NSDictionary dictionaryWithObject:@"Couldn't find Apple's installer tool!" forKey:NSLocalizedDescriptionKey]];
		[self finishInstallationToPath:installationPath withResult:NO host:host error:error delegate:delegate];
	} else {
		NSString *script = [NSString stringWithFormat:@"do shell script \"/usr/sbin/installer -pkg '%@' -target /\" with administrator privileges", path];
		NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:script, SUSilentPackageInstallerScriptKey, host, SUSilentPackageInstallerHostKey, delegate, SUSilentPackageInstallerDelegateKey, installationPath, SUSilentPackageInstallerInstallationPathKey, nil];
		if (synchronously) {
			[self performInstallationWithInfo:info];
		} else {
			[NSThread detachNewThreadSelector:@selector(performInstallationWithInfo:) toTarget:self withObject:info];
		}
	}
}

@end
