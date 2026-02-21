#!/bin/false
# Not a shell script, but something intended to be sourced from shell scripts

# This ensures that CL_PWD is a path understandable to CL.

cl_pwd() {
  CL_PWD="`pwd`"
  export CL_PWD
}
