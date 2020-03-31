#!/usr/bin/python

# This program creates the the resource-files for a specific worker (given as command-line-argument).

import os, sys, shutil, string


def createHostnameResources(hostname, kubefiles_path):

    print 'hostname: ' + hostname
    hostname_path = os.path.join(kubefiles_path, hostname)
    print 'hostname_path: ' + hostname_path

    # Remove the hostname-dir including its contents.
    try:
        shutil.rmtree(hostname_path)
    except Exception:
        pass

    # Make the new directory
    try:
        os.mkdir(hostname_path)
    except OSError:
        print ("Creation of the directory %s failed" % hostname_path)
        exit(-1)

    for filename in os.listdir(kubefiles_path):
        if filename.__contains__("exareme") and not filename.__contains__("master") and not filename.__contains__("keystore"):
            # copy file to new dir
            current_file_path = os.path.join(kubefiles_path, filename)
            filename = string.replace(filename, "exareme", "exareme-" + hostname)  # Rename the file.
            destination_file_path = os.path.join(hostname_path, filename)
            shutil.copyfile(current_file_path, destination_file_path)

            with open(destination_file_path, "r+") as file_object:
                lines = file_object.readlines()
                file_object.seek(0)
                for line in lines:
                    # Avoid changing the volume's path, the docker image and the env-variables
                    if not line.__contains__("path:") and not line.__contains__("mountPath:") and not line.__contains__("value:") and not line.__contains__("image:"):
                        line = string.replace(line, "exareme", "exareme-" + hostname)
                    file_object.write(line)


if __name__ == '__main__':

    args_num = len(sys.argv) - 1  # -1 as the first one is the script's name.
    if args_num != 1:
        raise Exception('Wrong number of arguments given: ' + args_num.__str__() + '. Expected number was <1>, the "hostname".')

    # Create a directory named after the hostname received as an argument
    hostname = sys.argv[1]
    kubefiles_path = os.getcwd()

    createHostnameResources(hostname, kubefiles_path)
