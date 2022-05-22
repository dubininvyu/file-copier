# file-copier
A 16-bits x86 DOS Assembly console utility for copying any file within one logical disk with FAT16 file system. 

# Theoretical basis
The first sector of logical disk, called the Boot Sector, contains the system area of file system. The relative number of the initial sector in the logical disk is 0. Behind the service structures is the area of files and directories, which is divided by the operating system into clusters. Clusters will be provided to the files and directories being created. Cluster numbering starts from 2.

The structure of the logical disk with FAT12/16 file system is shown below (in the table).

| Boot sector | FAT | FAT copy | Root catalog | Files and catalogs area |
|:----------------:|:---------:|:----------------:|:----------------:|:----------------:|

## Bot sector

The first sector of the logical disk is called the Boot Sector. The boot sector of a logical disk has the structure shown in the table below. 

| Jump to the boot | Boot record | Boot code | Control signature |
|:----------------:|:---------:|:----------------:|:----------------:|

The boot sector starts with three bytes of the `jmp` command to the bootloader, which is the boot of the operating system, if this logical disk is active. Next is the boot record – an information field with information about the logical disk, the parameters of the system area and the file system. Next is the boot code of the operating system, if this logical disk is active (that is, bootable). And, finally, the boot sector ends with a control signature – a two-byte code `55 AA`.

After formatting the logical disk, the boot record contains.
- Information about hard drive
- - Number of heads
- - Number of sectors on any disk track
- - Sector size
- - Hard drive number
- Information about logical disk
- - Logical disk size
- - Logical disk serial number
- - Logical disk letter
- Information about file system
- - File system type
- - Cluster size
- - Root catalog placement
- - FAT-tables placement

The logical disk numbers specified in the boot record are "logical", that is, counted from the beginning of the logical disk: 0, 1, 2, .... The format of the boot record is shown in table below.

| Field | Offset (from the sector beginning) | Size (bytes) |
|:----------------:|:---------:|----------------|
| System code | `03h` | 8 |
| Sector size (bytes) | `0Bh` | 2 |
| Cluster size (sectors) | `0Dh` | 1 |
| Reserved sectors | `0Eh` | 2 |
| Number of FAT-tables | `10h` | 1 |
| Root catalog size (records) | `11h` | 2 |
| Logical disk size (sectors) | `13h`  | 2 |
| Device descriptor | `15h` | 1 |
| FAT-table size (sectors) | `16h` | 2 |
| Number of sectors on any track | `18h` | 2 |
| Number of heads | `1Ah` | 2 |
| Number of hidden sectors | `1Ch` | 4 |
| Logical disk size (sectors) | `20h` | 4 |
| Hard drive number | `24h` | 1 |
| – | `25h` | 1 |
| Extended boot record | `26h` | 1 |
| Logical disk serial number | `27h` | 4 |
| Logical disk name | `2Bh` | 11 |
| File system name | `36h` | 8 |


Consider the fields of the boot record.

- `System code`. A text string (ASCII character codes) that is written by the operating system from which the logical disk is formatted.
- `Sector size`. Contains the value of the sector size in bytes – always 512.
- `Cluster size`. It is determined by the operating system during logical formatting based on the size of the logical disk and the preferences of the operating system.
- `Reserved sectors`. Sectors from the beginning of the logical disk to the FAT table.
- `Number of FAT-tables`. Defines the number of FAT tables - always 2: the main FAT table and its copy.
- `Root catalog size`. Sets the maximum number of entries in it – usually 512.
- `Device descriptor`. The code that characterizes the media environment. For hard media, this code is F8, for floppy disks (floppy disks) - F0.
- `Number of hidden sectors`. The number of sectors on the physical media before the start of this logical disk.
- `Hard drive number`. It is determined by the type of connected media. Physical disks are numbered 80h, 81h, 82h, 83h. Removable media numbers are maintained with 0: 0, 1, 2, ....
- `Extended boot record` Code 29h distinguishes modern FAT from earlier versions, where the boot record was shorter and contained less information.
- `Logical disk serial number`. A 4-byte numeric code generated when formatting a logical disk. Randomly generated from the current date and time data.
- `Logical disk name`. It is created with logical formatting and, in addition, placed in the root directory. The label is limited in size: 11 bytes is the maximum size of a text label.
- `File system name` Contains a text string with the name of the file system: FAT12, FAT16 or FAT32.

## File Allocation Table (FAT table).

When formatting, the area of the FAT logical disk intended for the placement of files and directories – objects of the file system will be divided into clusters. Cluster numbering starts from 2. The cluster size is selected depending on the type of FAT and the volume of the logical disk. The cluster size is always a multiple of a power of 2 and can be 1, 2, 4, 8, 16, 32 or 64 sectors. Accounting for the use of a logical FAT disk is carried out using the File Allocation Table (File Allocation Table – FAT table). The FAT table is an array of cluster descriptors (descriptors). One descriptor carries information about one logical disk cluster. The descriptor number corresponds to the number of the cluster being described.

The format of the FAT table is shown in table below.

| – | – | Cluster `2` descriptor | Cluster `3` descriptor | ... | Cluster `N` descrptor |
|:----------------:|:---------:|:----------------:|:----------------:|:----------------:|:----------------:|
| 0 | 1 | 2 | 3 | ... | N |

Descriptors numbered 0 and 1 are not used as cluster descriptors, since cluster numbering begins with 2. Thus, descriptor 0 contains a byte of the environment descriptor (from the boot sector), expanded as a signed number to the size of the field. Descriptor `1` is filled with `FFFF` code. After formatting a logical disk, all its clusters are "free", which means that the cluster descriptors in the FAT table are reset. When placing an object on a logical disk, free clusters are found for it according to information from the FAT table. The number of the initial cluster of the object is written to the parent directory. In each descriptor of the allocated clusters of the FAT table, the number of the subsequent cluster will be recorded, where the object body continues. And only in the descriptor of the last cluster will the code indicating the end of the chain of clusters allocated to the object be affixed. Thus, for each object (file or directory), the information in the Placement Table is a chain of links to the cluster numbers that it occupies. The number of the first cluster of this chain is contained in the directory entry about this object.
The cluster descriptor codes are shown in the table below.

| Cluster information | Descriptor |
|:----------------:|:---------:|
| Free cluster | `0000` |
| Defective cluster | `FFF7` |
| Reserved sector (by OS) | `FFF0` – `FFF6` |
| Occupied cluster (and it has a continution) | `0002` – `FFEF` |
| Occupied cluster (and the last one) | `FFF5` – `FFFF` |

The second FAT table is a backup copy of the first one and is synchronized with any changes in the first FAT table.

## File system object standard record

For each file and directory in the file system, a standard record is created that contains basic information about the object. The format of the standard record is shown in the table below.

| ASCII name | ASCII extension | Attributes | Addition information | Modified time | Modified data | Beginning cluster number | File size
|:----------------:|:---------:|:----------------:|:----------------:|:----------------:|:----------------:|:----------------:|:----------------:|
| 8 bytes | 3 bytes | 1 byte | 2 bytes | 2 bytes | 2 bytes | 2 bytes | 4 bytes |

The format of the addition information is shown in the table below.

| Name register | Created time (ms/10) | Created time | Created date | Last reading date | Modified data | Beginning cluster number |
|:----------------:|:---------:|:----------------:|:----------------:|:----------------:|:----------------:|:----------------:|
| 1 byte | 1 byte | 2 bytes | 2 bytes  2 bytes | 2 bytes | 4 bytes |

- `ASCII name` and `ASCII extension`. Object name and extension, written in 8.3 format in uppercase.
- `Byte attributes` Contains bit attributes of the properties of the element being described: a file, directory, or logical disk label. The attribute byte format is shown in the table below.
- `Beginning cluster number`. The number of the beginning cluster of the object.
- `File size` (bytes). Specifies the file size that this entry describes. For directories, the size is fixed – 0.

List of attributes: `R` (read-only), `H` ("hidden" when displaying the directory), `S` (system), `A` (archive), `D` (directory attribute), `V` (logical disk label attribute). 

| – | – | `A` | `D` | `V` | `S` | `H` | `R` |
|:----------------:|:---------:|:----------------:|:----------------:|:----------------:|:----------------:|:----------------:|:----------------:|
| 7 bit | 6 bit | 5 bit | 4 bit | 3 bit | 2 bit | 1 bit | 0 bit |

# Requirements and limitations
- Software access to logical disk or physical disk objects is performed at the sector level without using high-level operating system services.
- High-level services for application programs are used to access devices (keyboard input, screen output).
- In the path to the file system object entered from the keyboard, standard 8.3 format file/directory names are used in uppercase.
- The file system of the logical disk is FAT16.
- The maximum nesting of the file path is no more than 5 directories.
- The size of subdirectories in the object path is limited to one cluster.
- There are no additional restrictions on the size of the file to be copied (except for file system restrictions).
- The data for the utility is set by invitation.

# Environments

## Operating environment
The program is designed to run in a 16-bit operating environment running in real CPU mode, such as MSDOS. This is due to the fact that in the protected mode of the processor, attempts to directly access the hard disk sectors will be blocked by the operating system.

## Development environment
Assembler program development was performed in such a development environment as Borland Turbo Assembler (TASM) - Borland software package designed to develop assembly language programs for x86 architecture.

## Debugging environment
Assembler program debugging was performed in such a debugging environment as Borland Turbo Assembler (TASM) - Borland software package designed to develop assembly language programs for x86 architecture.

# Using the utility
The program is run from the command line.

At the beginning, the program invites the user to enter the path to the file to be copied, with a text message "Please, enter the path to your file". After receiving an input prompt, the user enters the path to the file in the 8.3 format in uppercase.

After getting the path to the file, the program checks the letter of the logical disk. A logical disk can have a letter in the range A...Z. If the letter of the logical disk is incorrect, the user receives a text message on the screen "The path to your file is wrong", and the program terminates its work.

The program generates an array of names. In case of errors in the process of forming an array of names, the user receives the message "The path to your file is wrong" on the screen, and the program terminates its work.

In the process of forming an array of names, the program counted the number of nested directories in the file path. Next, the program checks the counted number. If the number of directories exceeds the value of 5, the user receives a text message on the screen "Your path contains too many directories", and the program shuts down.

The program receives information about the logical disk: the type of file system, cluster size, number of reserved sectors, the size of the root directory in sectors, the size of the FAT table. Next, a check is performed to see if the file system of this logical disk is a FAT16 file system. If the logical disk has a different file system, the user receives a text message on the screen "This logical disk is not FAT16", and the program terminates its work.

System structures are calculated: sector number of the first FAT table, sector number of the second FAT table, sector number of the root directory, sector number of the first cluster.

Searches for a standard record of the file to be copied and saves it. If there is no file on the specified path on the logical disk, the user receives a text message on the screen "The path to your file is wrong", and the program terminates its work.

Determining the number of clusters occupied by the file to be copied. Next, search for the required number of free clusters in the FAT table and link them into a cluster chain. If there are no free descriptors in the FAT table, the user receives a text message on the screen "There is no so much space in your logical disk", and the program terminates its work.

The first cluster of the copy file is written to the standard entry in the corresponding byte - the "Number of the initial cluster".

The program invites the user to enter the path to the directory, a copy of the file in which you want to create, with a text message "Please, enter the path to your file". After receiving an input prompt, the user enters the directory path in the 8.3 format in uppercase.

After getting the path to the directory, the program checks the letter of the logical disk. The logical disk on which the file for copying is located and the logical disk in which a copy of the file should be placed must be identical. If the logical disks are different, the user receives a text message on the screen "Both paths have different logical disks", and the program terminates its work.

The program generates an array of names. In case of errors during the formation of an array of names, the user receives the message "The path to your directory is wrong" on the screen, and the program terminates its work.

In the process of forming an array of names, the program counted the number of nested directories in the path. Next, the program checks the counted number. If the number of directories exceeds the value of 5, the user receives a text message on the screen "Your path contains too many directories", and the program shuts down.
A search is performed for a standard entry about the directory in which you want to place a copy of the file. If there is no directory on the specified path on the logical disk, the user receives a text message on the screen "The path to your directory is wrong", and the program terminates its work.

With the help of a standard directory entry, the program reads sectors with the body of the directory in which it is necessary to place a copy, and places the standard file entry in a free entry. If a file with the same name already exists in the selected directory, the user receives a text message "Selected file already exists in this directory" on the screen, and the program shuts down. If there is no free space in the directory, the user receives a text message on the screen "There is no so much space in your logical disk", and the program terminates its work.

The updated sector with the body of the directory and the edited FAT table is written to the hard drive. Next – synchronization with a copy of the FAT table.
The program copies all sectors in which the body of the file to be copied is located to the sectors belonging to the copy file by sequential reads and writes.
In case of unexpected errors when reading or writing sectors, the user receives text messages on the screen "Invalid sector reading..." and "Invalid sector writing", respectively, after which the program terminates its work.

And finally, in case of successful operation of the program, the user receives a message on the screen: "A copy of the wile was created", after which the program stops working.

# Program structure

Segmented program structure:
- Code segment (pointer is `CS`)
- Data segment (pointer is `DS`) – for placing data in the memory.
- Code segment (pointer is `CS`) - for procedures.

## Variables

| Name | Size (bytes) | Assignment |
|:----------------:|:---------:|----------------|
| `sector1` | 512 | Buffer for placing bytes from the sector |
| `sector2` | 512 | Buffer for placing bytes from the sector |
| `sector3` | 512 | Buffer for placing bytes from the sector |
| `msg_inp_path` | 82 | Input are to the file |
| `msg_inp_copy_path` | 82 | Input are to the file copy |
| `names_array` | 7 x 11 = 77 | Names array to the file |
| `names_array_copy` | 7 x 11 = 77 | Names array to the catalog |
| `file_dirs` | 1 | Number of directories to the file path |
| `file_cluster_begin` | 2 | Beginning cluster number (to the file) |
| `file_cluster_size` | 2 | File size (clusters) |
| `copy_cluster_begin` | 1 | Beginning cluster number (to the catalog) |
| `copy_cluster_size` | 1 | Catalog size (clusters) |
| `record_file` | 32 | File standard record |
| `last_dscrpt` | 2 | Temporary variable |
| `counter1` | 2 | Counter |
| `temp_sec⁡_num` | 2 | Temporary variable |
| `next_cluster1` | 2 | The next cluster for the reading |
| `next_cluster2` | 2 | The next cluster for the reading |
| `next_sector1` | 4 | The next sector for the reading |
| `next_sector2` | 4 | The next sector for the reading |
| `ld_number` | 4 | Logical disk number |
| `cluster_size` | 1 | Cluster size |
| `root_begin` | 1 | root begin sector number |
| `root_size` | 2 | root size (sectors) |
| `fat1_begin` | 4 | FAT table sector number |
| `fat2_begin` | 4 | FAT table copy sector number |
| `fat_size` | 2 | FAT table size (sectors) |
| `sec1_begin` | 4 | Cluster area sector number |
| `s_reserved_sectors` | 2 | Number of reserved sectors |
| `packet_proc` | 7 x 2 = 14 | Standard record packet |
| `packet_int` | 10 | Interrupt packet |
| `file_system` | – | File system name (FAT16) |
| `msg_success` | – | `A copy of the file was created` |
| `msg_ent_path` | – | `Please, enter the path: ` |
| `msg_err_sector_reading` | – | `Invalid sector reading...` |
| `msg_err_sector_writing` | – | `Invalid sector writing...` |
| `msg_err_copy_path` | – | `The path to your file is wrong` |
| `msg_err_too_much_dirs` | – | `Your path consists too much directories` |
| `msg_err_file_system` | – | `This logical disk is not FAT16` |
| `msg_err_no_space` | – | `There is no so much space in your logical disk` |
| `msg_err_diff_ld` | – | `Both paths have different logical disks` |
| `msg_err_file_exists` | – | `Selected file already exists in this directory` |

## Constants

| Name | Value | Assignment |
|:----------------:|:---------:|----------------|
| `BR_CLUSTER_SIZE` | `0Dh` | Cluster syze (1 byte) |
| `BR_RESERVED_SECTORS` | `0Eh` | Number of sectors up to the FAT-table (2 bytes) |
| `BR_ROOT_CATALOG_SIZE` | `11h` | Root size in records (2 bytes) |
| `BR_FAT_SIZE` | `16h` | FAT sizes (2 bytes) |
| `BR_FILE_SYSTEM` | `36h` | File system (8 bytes, 'FAT16   ') |
| `SR_ATTRIBUTE` | `0Bh` | Offset from the beginning of a standard record to the attribute byte |
| `SR_CLUSTER_BEGIN` | `1Ah` | Offset from the beginning of a standard record to the cluster begin |

## Procedures

1. `get_ld_number` procedure.

Description: converts a logical disk letter written in uppercase to a number and checks whether the logical disk number is correct.

Parameters: 
- `SI` – the address of the logical drive letter.
- Return `SI` – logical disk number.
- Return `CF` – error flag (CF=1 - error).

2. `get_sector_number` procedure.

Description: calculates the sector number by the number of the first sector in the cluster area (`EBX`), cluster size (`CL`) and cluster number (`AX`).

Parameters: 
- `EBX` – the number of the first sector of the cluster area.
- `CL` – cluster size.
- `AX` – cluster number.
- Return `EBX` – sector number.

3. `find_record` procedure.

Description: searches for a standard entry about a file or directory based on the path from an array of names.

Parameters: 
- `SI` – address of the procedure package.
- `CF` – search object attribute: 0 – directory, 1 – file.
- Return `BP` – the address of the beginning of the standard record from the beginning of the sector.
- Return `CF` – error flag (CF=1 - error).

The procedure packet format is shown in the table below.

| Offset (bytes) | Name | Field size (bytes) |
|:----------------:|:---------:|----------------|
| 0 | The address in memory with the logical disk number | 2 |
| 2 | Address in memory with cluster size | 2 |
| 4 | The address in memory with the sector number of the root directory | 2 |
| 6 | Address in memory with the size of the root directory | 2 |
| 8 | The address in memory with the number of the first sector of the cluster area | 2 |
| 1A | The address in memory with the number of nested directories in the path to the object | 2 |
| 1C | Address in memory with an array of names | 2 |

4. `get_names_array` procedure. 

Description: generates an array of names from a string – the path to a file or directory.

Parameters: 
- `SI` – the input area address.
- `BP` – the names array address.
- `CF` – the attribute of the destination object in the path: 0 – file, 1 – directory.
- Return `BL` – the number of nested directories in the object path.
- Return `CF` – error flag (CF=1 - error).

## Macros

1. Macro `throw_ne`.

Description: enters the message specified in the message parameter and proceeds to the "Message output" block if `ZF=0`.

Parameters:
- `message` – text message to be displayed on the screen.

2. Macro `throw_c`.

Description: enters the message specified in the message parameter and proceeds to the "Message output" block if `CF=1`.

Parameters:
- `message` – text message to be displayed on the screen.

3. Macro `throw_z`.

Description: enters the message specified in the message parameter and proceeds to the "Message output" block if `ZF=1`.

Parameters:
- `message` – text message to be displayed on the screen.

4. Macro `throw_g`.

Description: enters the message specified in the message parameter and proceeds to the "Message output" block if `CF = (OF & ZF)`.

Parameters:
- `message` – text message to be displayed on the screen.

5. Macro `read_sector`.

Description: reads a sector on the hard disk with the `drive` number with the `packet` of the disk address `packet`. After reading the sector it uses the macro command `throw_c` with the `message` parameter.

Parameters:
- `ld_number` – the number of the logical disk drive from which you want to read.
- `packet` – intra-segment packet address of the disk address.
- `message` – text message to be displayed on the screen.

6. Macro 'write_sector'.

Description: writes a sector to a logical disk with the `ld_number` number with the packet package. After reading the sector, it uses the `throw_c` macro with the message parameter.

Parameters:
- `ld_number` – the number of the logical disk drive from which you want to read.
- `packet` – intra-segment packet address of the disk address.
- `message` – text message to be displayed on the screen.

7. Macro 'print_msg'.

Description: print `message` to the screen.

Parameters:
- `ld_number` – the number of the logical disk drive from which you want to read.
- `packet` – intra-segment packet address of the disk address.
- `message` – text message to be displayed on the screen.

8. Macro 'enter_msg'.

Description: buffered text input from the keyboard to the input area area.

Parameters:
- `area` – input area.
