# This template is not my original work. All rights goes to Schokokeks for creating the original template.

### Guide
This template is derived from Schokokek's template, meaning that most of its functionality can be done with this template.

Due to the port, this template may be highly unstable. Please contact Snoresville#2486 via Discord with details of any errors.

### Installation
Download/Clone the files and add said files to the respective compartments of your Dota 2 local files
- Files in content/dota_addons/addon_template_overthrow_butt should be placed in its respective path.
- Files in game/dota_addons/addon_template_overthrow_butt should be placed in its respective path.

### Version Control
To utilize version control (e.g. GitHub + GitHub Desktop), you'll need to use Junctions to link files from your repo (repository) folder to your addon folders.

The usage of this mechanism allows you to keep an organised repo folder stored separately from Dota's local files + saves headaches with your IDE while also ensuring that changes you make with files in your repo will be matched in Dota 2's local files.

If you're a Windows user (e.g. Snoresville), you can make a Junction with the Command Prompt (you already have this the moment you had Windows).

``mklink /J <path to ghost folder> <path to actual folder>``

The first parameter after ``/J`` is the start of the Junction link, creating a "folder" that when opened, will lead to the folder you've linked to in the second parameter.

The path to the ghost folder **MUST NOT EXIST;** 

### Differences between this and the original

Kill limit and time limit are no longer alternate winning conditions in the Overthrow version of the template.

# Original Templates
https://github.com/Jochnickel/addon_template_butt - Schokokeks' original version

https://github.com/BOTRaiquia/dota2buttemplate_fixed - Raiquia's improved version
