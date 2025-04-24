## macOS-Jailbreak
Tutorial on how to jailbreak Apple Silicon Macs

Tested on macOS 14 and macOS 15

This guide is very technical and will take some time to complete on the first attempt. If you aren't comfortable disabling System Integrity Protection (SIP) or the Secured System Volume (SSV) please do not continue with the guide. This will lower system security substantially, but that's kind of the goal. This guide will allow you to moddify system files and folders, install any iOS app in the form of a .ipa on your system, and use iOS tweaks in the form of dylibs on macOS with the help of ellekit.

## Preliminary Note about updates

You can still update macOS after following this guide, HOWEVER, when attempting to update re-enable SIP in 1 True Recovery. This will erase all rootfs changes, custom kernel changes, and dyld changes. This is REQUIRED to update, if you do not do this beforehand your system will bootloop after the update has been applied, this can be fixed though by re-enabling SIP. After an update you will need to redo the entire guide. I'm not sure how Rapid Security Releases (RSRs) react to these changes, it can be assumed that they would either fail or cause issues. Apple hasn't pushed any RSRs in the past two years though so it can be assumed that RSRs are dead (The last RSR that was pushed was for macOS 13.3.1).

I am not responsible for any damage caused by following these instructions. Please make sure you have a backup of your data beforehand as things could go wrong.
Let us begin!

# 1. Kernel Patches


## 1a. Compiling & Using img4

First, we will need to do two kernel patches, a trustcache patch, along with a file system mounting patch

You'll need to compile img4lib from source on your Mac machine as there are no currently available arm64 binaries:

`git clone --recursive https://github.com/xerub/img4lib.git`

Install lzfse and openssl from homebrew:

`brew install lzfse openssl@3`

Edit the Makefile for img4lib:

`nano Makefile`

Add a CFLAGS line:

`CFLAGS += -I/opt/homebrew/include`

And an LDFLAGS line:

`LDFLAGS += -L/opt/homebrew/lib`

Compile the project:

`make`

You will now have a binary of img4, I recommend moving it to /usr/local/bin

To keep things organized I'm going to be creating a folder named Jailbreak in my home directory:

`mkdir -p ~/Jailbreak`

`cd ~/Jailbreak mkdir KPatch`

`cd KPatch`

To begin with the kernel modifications we will need to use img4 on our current kernelcache:

`img4 -i /System/Volumes/Preboot/*/boot/*/System/Library/Caches/com.apple.kernelcaches/kernelcache -o kcache.raw`

I recommend creating a copy of your original kernelcache just in case any modifications go wrong:

`cp -v kcache.raw kcache.raw.backup`

Copy the extracted kernelcache to new file, allowing us to create a patched version:

`cp -v kcache.raw kcache.patched`

## 1b. Trustcache Patch

We will be using Radare2 for the first patch, install it using homebrew:

`brew install radare2`

Open our ready to patch kernelcache in Radare2:

`r2 -w kcache.patched`

When Radare2 is finished initializing all the kexts, type in this command to find the location for our patch, you should get one result. Copy this address and keep it safe.

        /x e0030091e10313aa000000949f020071e0179f1a:ffffffffffffffff000000fcffffffffffffffff

[Source](https://github.com/palera1n/PongoOS/blob/iOS15/checkra1n/kpf/trustcache.c) for trustcache patch


We need to write new instructions in Radare2, to do this type "v" to enter visual mode, then type "g" and paste in the address you found earlier. 
When you are at the address use "j" and "j" to scroll up and down respectively. 
We will need to scroll up a few lines. Once you've scrolled up type "a" to enter the assembler mode. 
You're going to want to find the `AMFIIsCDHashInTrustCache` function, below this function you should see an instruction named `pacibsp`. 
Save the address for this instruction "q" to quit out of assembler mode, you should be back in visual mode. 
Type "g" and go to the address of the `pacibsp` instruction, then type "a" to enter assembler mode again. 
Once in assembler mode at the instruction replace the instructions with:

        mov x0, 1; cbz x2, .+0x8; str x0, [x2]; ret

Press "return" to save the changes and press "q" to exit assembler mode, then press "q" and "return" again to exit Radare2.

## 1c. Read/Write RootFS Patch

Now we need to apply the read/write rootfs patch. Use KPlooshFinder to apply this patch. I recommend moving the binary to /usr/local/bin
Use KPlooshFinder on our patched kernel to apply the second patch.

`KPlooshFinder kcache.patched kcache.readwrite`

## 1d. Reducing Security & Installing the Kernel

We will now need to reboot into 1 True Recovery (1TR). To enter 1TR shut down your Mac, do not press restart. Once your Mac is off press and hold down the power button, you will see "Continue holding for startup options...". Keep holding down the power button until you see "Loading startup options...", at this point you can stop holding the button down.

Once you are in startup options menu select "Options" with the settings icon. Type your password to authenticate then open terminal by pressing "Utilities" at the top of the menu bar.

We will need to disable System Integrity Protection and the Secure System Volume. We will also need to install the custom kernel, along with reboot back into normal mode. Run these 4 commands:

Disable SIP:

`csrutil disable`

Disable SSV:

`csrutil authenticated-root disable`

Install Kernel:

`kmutil configure-boot -v /Volumes/Macintosh\ HD -c /Volumes/Data/Users/[Username]/Jailbreak/KPatch/kcache.readwrite`

Reboot the system:

`reboot`

We will need to add boot arguments now to further relax system restrictions. Run these commands (The `-v` is optional, all it does is enable verbose booting):

`sudo nvram boot-args="-arm64e_preview_abi amfi_get_out_of_my_way=1 ipc_control_port_options=0 -v"`

`reboot`

# 2. Dyld Patches

We will need to now begin patching dyld. I'm going to stay organized and keep these files in a different directory

`cd ~/Jailbreak`

`mkdir DPatch`

`cd DPatch`

Copy dyld into our workspace and create a backup:

`cp -v /usr/lib/dyld ./dyld`
        
`cp -v dyld dyld.backup`

The patches for dyld are:

[Dopamine's Patch](https://github.com/opa334/Dopamine/blob/2.x/BaseBin/jbctl/src/dyldpatch.m#L11-L22)

[Palera1n's DYLD_IN_CACHE Patch](https://github.com/palera1n/jbinit/blob/c1015df65dad3704ace43feb6ebc310542c60422/src/fakedyld/patch_dyld/patcher.c#L51)

## 2a. Dopamine's Patch

Open dyld in Binary Ninja, make sure to select the arm64e slice, then go to the symbol for the Dopamine patch, and set it to (If you can't find the symbol, try searching for the demangled one):

        mov x0, 0xdf; ret

Dopamine Symbol:

        __ZN5dyld413ProcessConfig8Security7getAMFIERKNS0_7ProcessERNS_15SyscallDelegateE

Demangled Symbol:

        _dyld4::ProcessConfig::Security::getAMFI(dyld4::ProcessConfig::Process const&, dyld4::SyscallDelegate&)

## 2b. Palera1n's DYLD_IN_CACHE Patch

Search DYLD_IN_CACHE
Then go to the xref (Cross references, should be located at the bottom left of Binja)
Find this pattern:

        0xaa1303e0, // mov x0, x19
        0x94000000, // bl dyld4::KernelArgs::findEnvp
        0x90000001, // adrp x1, "DYLD_IN_CACHE"@PAGE
        0x91000021, // add x1, "DYLD_IN_CACHE"@PAGEOFF
        0x94000000, // bl __simple_getenv
        0xb4000000, // cbz x0, ...
        0x90000001, // adrp x1, "0"@PAGE
        0x91000021, // add x1, "0"@PAGEOFF
        0x94000000, // bl strcmp
        0x34000000  // cbz w0, ...

Replace the pattern with:

        stream[5] = 0xd503201f; /* nop */
        stream[8] = 0x52800000; /* mov w0, #0 */
        
This will make it so it never gets called.
Save changes with cmd+s

Run these two commands to mount the root filesystem as read/write, and to create another backup of dyld.

`sudo mount -uw /`

`sudo cp -v /usr/lib/dyld /usr/lib/dyld.backup`

You will need to use ldid on dyld, you can get ldid from Procursus. There's a guide on how to get Procursus installed on the Procursus Discord.

`ldid -S dyld -Icom.apple.darwin.ignition`

Type this command to replace dyld, this will cause every process on your system to be killed. Force restart by holding the power button.

`sudo cp -v dyld /usr/lib/dyld`

# 3. Installing Ellekit
Ellekit is the tweak injection platform we will be using for certain tweaks, such as AppSync
Install Ellekit by compiling it from source. Type these commands to clone Ellekit's repo, make it for macOS.

`git clone https://github.com/tealbathingsuit/ellekit`

`MAC=1 make`

There should be a tar.gz file in the packages folder inside the repo. Rename the file to ellekit.tar.gz then run this command (You'll get an error about timestamps, ignore it):

`sudo tar -xvf ellekit.tar.gz -C /`

Resign the loader with loader.xml:

`ldid -Sloader.xml /usr/local/bin/loader`

Copy the loader to /Library/TweakInject/loader:

`sudo cp -v /usr/local/bin/loader /Library/TweakInject/loader`

Place the launch daemon from com.evln.ellekit.startup.plist to /Library/LaunchDaemons:

`sudo cp -v com.evln.ellekit.startup.plist /Library/LaunchDaemons/com.evln.ellekit.startup.plist`

Set the correct permissions & reboot:

`sudo chmod 644 /Library/LaunchDaemons/com.evln.ellekit.startup.plist`

`sudo chown root:wheel /Library/LaunchDaemons/com.evln.ellekit.startup.plist`

`reboot`

Make a CydiaSubstrate symlink for easy tweak injection:

`sudo mkdir -p /Library/Frameworks/CydiaSubstrate.framework`

`sudo ln -s /Library/TweakInject/ellekit.dylib /Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate`

# 4. Installing AppSync
 
To setup Theos for macOS you need to move this directory, move it back after you've successfully compiled AppSync

`mv ~/theos/vendor/include/IOKit ~/theos/vendor/include/IOKit.bak`

`mv ~/theos/vendor/include/IOKit.bak ~/theos/vendor/include/IOKit`

You'll need to compile appsync for macOS, you only need the installd dylib and the plist included with it
Put both of them in: `/Library/TweakInject`

Add macosx to the CydiaSubstrate, otherwise it wont link

Reboot once more and you should now have a jailbroken Mac machine. Double click any ipa and it will successfully install. Installed apps will need to be resigned before they are able to run. You can use the .sh script provided to resign apps

# 5. Optional Tweaks

These tweaks are optional, but can be useful. 

## Mounting root as read/write on boot
By default the root filesystem is not mounted as r/w when starting macOS. This can be an issue if you frequently work within protected folders.
Add the plist file `com.nathan.mount.plist` to `/Library/LaunchDaemons` to automatically mount the root filesystem as read/write on boot.
