# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

include_guard()

include(FetchContent)

FetchContent_Declare(jemalloc
  GIT_REPOSITORY https://github.com/jemalloc/jemalloc
  GIT_TAG 12cd13cd418512d9e7596921ccdb62e25a103f87
)

FetchContent_GetProperties(jemalloc)
if(NOT jemalloc_POPULATED)
  FetchContent_Populate(jemalloc)

  execute_process(COMMAND autoconf
    WORKING_DIRECTORY ${jemalloc_SOURCE_DIR}
  )
  execute_process(COMMAND ${jemalloc_SOURCE_DIR}/configure -C --enable-autogen --disable-libdl --with-jemalloc-prefix=""
    WORKING_DIRECTORY ${jemalloc_BINARY_DIR}
  )
  add_custom_target(make_jemalloc 
    COMMAND make
    WORKING_DIRECTORY ${jemalloc_BINARY_DIR}
  )
endif()

find_package(Threads REQUIRED)

add_library(jemalloc INTERFACE)
target_include_directories(jemalloc INTERFACE $<BUILD_INTERFACE:${jemalloc_BINARY_DIR}/include>)
target_link_libraries(jemalloc INTERFACE $<BUILD_INTERFACE:${jemalloc_BINARY_DIR}/lib/libjemalloc.a> Threads::Threads)
add_dependencies(jemalloc make_jemalloc)
