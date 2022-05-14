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

# Copyright (c) 2006-2020, Salvatore Sanfilippo
# See bundled license file licenses/LICENSE.redis for details.

# This file is copied and modified from the Redis project,
# which started out as: https://github.com/redis/redis/blob/dbcc0a8/tests/unit/type/set.tcl

start_server {
    tags {"set"}
} {
    proc create_set {key entries} {
        r del $key
        foreach entry $entries { r sadd $key $entry }
    }

    test {SADD, SCARD, SISMEMBER, SMEMBERS basics - regular set} {
        create_set myset {foo}
        #assert_encoding hashtable myset
        assert_equal 1 [r sadd myset bar]
        assert_equal 0 [r sadd myset bar]
        assert_equal 2 [r scard myset]
        assert_equal 1 [r sismember myset foo]
        assert_equal 1 [r sismember myset bar]
        assert_equal 0 [r sismember myset bla]
        assert_equal {bar foo} [lsort [r smembers myset]]
    }

    test {SADD, SCARD, SISMEMBER, SMEMBERS basics - intset} {
        create_set myset {17}
        #assert_encoding intset myset
        assert_equal 1 [r sadd myset 16]
        assert_equal 0 [r sadd myset 16]
        assert_equal 2 [r scard myset]
        assert_equal 1 [r sismember myset 16]
        assert_equal 1 [r sismember myset 17]
        assert_equal 0 [r sismember myset 18]
        assert_equal {16 17} [lsort [r smembers myset]]
    }

    test {SADD against non set} {
        r lpush mylist foo
        assert_error *WRONGTYPE* {r sadd mylist bar}
    }

    test "SADD a non-integer against an intset" {
        create_set myset {1 2 3}
        #assert_encoding intset myset
        assert_equal 1 [r sadd myset a]
        #assert_encoding hashtable myset
    }

    test "SADD an integer larger than 64 bits" {
        create_set myset {213244124402402314402033402}
        #assert_encoding hashtable myset
        assert_equal 1 [r sismember myset 213244124402402314402033402]
    }

    test "SADD overflows the maximum allowed integers in an intset" {
        r del myset
        for {set i 0} {$i < 512} {incr i} { r sadd myset $i }
        #assert_encoding intset myset
        assert_equal 1 [r sadd myset 512]
        #assert_encoding hashtable myset
    }

    test {Variadic SADD} {
        r del myset
        assert_equal 3 [r sadd myset a b c]
        assert_equal 2 [r sadd myset A a b c B]
        assert_equal [lsort {A a b c B}] [lsort [r smembers myset]]
    }

    test {SREM basics - regular set} {
        create_set myset {foo bar ciao}
        #assert_encoding hashtable myset
        assert_equal 0 [r srem myset qux]
        assert_equal 1 [r srem myset foo]
        assert_equal {bar ciao} [lsort [r smembers myset]]
    }

    test {SREM basics - intset} {
        create_set myset {3 4 5}
        #assert_encoding intset myset
        assert_equal 0 [r srem myset 6]
        assert_equal 1 [r srem myset 4]
        assert_equal {3 5} [lsort [r smembers myset]]
    }

    test {SREM with multiple arguments} {
        r del myset
        r sadd myset a b c d
        assert_equal 0 [r srem myset k k k]
        assert_equal 2 [r srem myset b d x y]
        lsort [r smembers myset]
    } {a c}

    test {SREM variadic version with more args needed to destroy the key} {
        r del myset
        r sadd myset 1 2 3
        r srem myset 1 2 3 4 5 6 7 8
    } {3}

    foreach {type} {hashtable intset} {
        for {set i 1} {$i <= 5} {incr i} {
            r del [format "set%d" $i]
        }
        for {set i 0} {$i < 200} {incr i} {
            r sadd set1 $i
            r sadd set2 [expr $i+195]
        }
        foreach i {199 195 1000 2000} {
            r sadd set3 $i
        }
        for {set i 5} {$i < 200} {incr i} {
            r sadd set4 $i
        }
        r sadd set5 0

        # To make sure the sets are encoded as the type we are testing -- also
        # when the VM is enabled and the values may be swapped in and out
        # while the tests are running -- an extra element is added to every
        # set that determines its encoding.
        set large 200
        if {$type eq "hashtable"} {
            set large foo
        }

        for {set i 1} {$i <= 5} {incr i} {
            r sadd [format "set%d" $i] $large
        }

        test "Generated sets must be encoded as $type" {
            for {set i 1} {$i <= 5} {incr i} {
                #assert_encoding $type [format "set%d" $i]
            }
        }

        test "SINTER with two sets - $type" {
            assert_equal [list 195 196 197 198 199 $large] [lsort [r sinter set1 set2]]
        }

        test "SINTERSTORE with two sets - $type" {
            r sinterstore setres set1 set2
            #assert_encoding $type setres
            assert_equal [list 195 196 197 198 199 $large] [lsort [r smembers setres]]
        }

        test "SUNION with two sets - $type" {
            set expected [lsort -uniq "[r smembers set1] [r smembers set2]"]
            assert_equal $expected [lsort [r sunion set1 set2]]
        }

        test "SUNIONSTORE with two sets - $type" {
            r sunionstore setres set1 set2
            #assert_encoding $type setres
            set expected [lsort -uniq "[r smembers set1] [r smembers set2]"]
            assert_equal $expected [lsort [r smembers setres]]
        }

        test "SINTER against three sets - $type" {
            assert_equal [list 195 199 $large] [lsort [r sinter set1 set2 set3]]
        }

        test "SINTERSTORE with three sets - $type" {
            r sinterstore setres set1 set2 set3
            assert_equal [list 195 199 $large] [lsort [r smembers setres]]
        }

        test "SUNION with non existing keys - $type" {
            set expected [lsort -uniq "[r smembers set1] [r smembers set2]"]
            assert_equal $expected [lsort [r sunion nokey1 set1 set2 nokey2]]
        }

        test "SDIFF with two sets - $type" {
            assert_equal {0 1 2 3 4} [lsort [r sdiff set1 set4]]
        }

        test "SDIFF with three sets - $type" {
            assert_equal {1 2 3 4} [lsort [r sdiff set1 set4 set5]]
        }

        test "SDIFFSTORE with three sets - $type" {
            r sdiffstore setres set1 set4 set5
            # When we start with intsets, we should always end with intsets.
            if {$type eq {intset}} {
                #assert_encoding intset setres
            }
            assert_equal {1 2 3 4} [lsort [r smembers setres]]
        }
    }

    test "SDIFF with first set empty" {
        r del set1 set2 set3
        r sadd set2 1 2 3 4
        r sadd set3 a b c d
        r sdiff set1 set2 set3
    } {}

    test "SDIFF with same set two times" {
        r del set1
        r sadd set1 a b c 1 2 3 4 5 6
        r sdiff set1 set1
    } {}

    test "SDIFF fuzzing" {
        for {set j 0} {$j < 100} {incr j} {
            unset -nocomplain s
            array set s {}
            set args {}
            set num_sets [expr {[randomInt 10]+1}]
            for {set i 0} {$i < $num_sets} {incr i} {
                set num_elements [randomInt 100]
                r del set_$i
                lappend args set_$i
                while {$num_elements} {
                    set ele [randomValue]
                    r sadd set_$i $ele
                    if {$i == 0} {
                        set s($ele) x
                    } else {
                        unset -nocomplain s($ele)
                    }
                    incr num_elements -1
                }
            }
            set result [lsort [r sdiff {*}$args]]
            assert_equal $result [lsort [array names s]]
        }
    }

    test "SINTER against non-set should throw error" {
        r set key1 x
        assert_error "*WRONGTYPE*" {r sinter key1 noset}
    }

    test "SUNION against non-set should throw error" {
        r set key1 x
        assert_error "*WRONGTYPE*" {r sunion key1 noset}
    }

    test "SINTER should handle non existing key as empty" {
        r del set1 set2 set3
        r sadd set1 a b c
        r sadd set2 b c d
        r sinter set1 set2 set3
    } {}

    test "SINTER with same integer elements but different encoding" {
        r del set1 set2
        r sadd set1 1 2 3
        r sadd set2 1 2 3 a
        r srem set2 a
        #assert_encoding intset set1
        #assert_encoding hashtable set2
        lsort [r sinter set1 set2]
    } {1 2 3}

    test "SINTERSTORE against non existing keys should delete dstkey" {
        r set setres xxx
        assert_equal 0 [r sinterstore setres foo111 bar222]
        assert_equal 0 [r exists setres]
    }

    test "SUNIONSTORE against non existing keys should delete dstkey" {
        r set setres xxx
        assert_equal 0 [r sunionstore setres foo111 bar222]
        assert_equal 0 [r exists setres]
    }

    foreach {type contents} {hashtable {a b c} intset {1 2 3}} {
        test "SPOP basics - $type" {
            create_set myset $contents
            #assert_encoding $type myset
            assert_equal $contents [lsort [list [r spop myset] [r spop myset] [r spop myset]]]
            assert_equal 0 [r scard myset]
        }

        test "SPOP with <count>=1 - $type" {
            create_set myset $contents
            #assert_encoding $type myset
            assert_equal $contents [lsort [list [r spop myset 1] [r spop myset 1] [r spop myset 1]]]
            assert_equal 0 [r scard myset]
        }

        # test "SRANDMEMBER - $type" {
        #     create_set myset $contents
        #     unset -nocomplain myset
        #     array set myset {}
        #     for {set i 0} {$i < 100} {incr i} {
        #         set myset([r srandmember myset]) 1
        #     }
        #     assert_equal $contents [lsort [array names myset]]
        # }
    }

    foreach {type contents} {
        hashtable {a b c d e f g h i j k l m n o p q r s t u v w x y z} 
        intset {1 10 11 12 13 14 15 16 17 18 19 2 20 21 22 23 24 25 26 3 4 5 6 7 8 9}
    } {
        test "SPOP with <count>" {
            create_set myset $contents
            #assert_encoding $type myset
            assert_equal $contents [lsort [concat [r spop myset 11] [r spop myset 9] [r spop myset 0] [r spop myset 4] [r spop myset 1] [r spop myset 0] [r spop myset 1] [r spop myset 0]]]
            assert_equal 0 [r scard myset]
        }
    }

    # As seen in intsetRandomMembers
    test "SPOP using integers, testing Knuth's and Floyd's algorithm" {
        create_set myset {1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20}
        #assert_encoding intset myset
        assert_equal 20 [r scard myset]
        r spop myset 1
        assert_equal 19 [r scard myset]
        r spop myset 2
        assert_equal 17 [r scard myset]
        r spop myset 3
        assert_equal 14 [r scard myset]
        r spop myset 10
        assert_equal 4 [r scard myset]
        r spop myset 10
        assert_equal 0 [r scard myset]
        r spop myset 1
        assert_equal 0 [r scard myset]
    } {}

    test "SPOP using integers with Knuth's algorithm" {
        r spop nonexisting_key 100
    } {}

    test "SPOP new implementation: code path #1" {
        set content {1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20}
        create_set myset $content
        set res [r spop myset 30]
        assert {[lsort $content] eq [lsort $res]}
    }

    test "SPOP new implementation: code path #2" {
        set content {1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20}
        create_set myset $content
        set res [r spop myset 2]
        assert {[llength $res] == 2}
        assert {[r scard myset] == 18}
        set union [concat [r smembers myset] $res]
        assert {[lsort $union] eq [lsort $content]}
    }

    test "SPOP new implementation: code path #3" {
        set content {1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20}
        create_set myset $content
        set res [r spop myset 18]
        assert {[llength $res] == 18}
        assert {[r scard myset] == 2}
        set union [concat [r smembers myset] $res]
        assert {[lsort $union] eq [lsort $content]}
    }

    test "SRANDMEMBER with <count> against non existing key" {
        r srandmember nonexisting_key 100
    } {}

    proc setup_move {} {
        r del myset3 myset4
        create_set myset1 {1 a b}
        create_set myset2 {2 3 4}
        #assert_encoding hashtable myset1
        #assert_encoding intset myset2
    }

    test "SMOVE basics - from regular set to intset" {
        # move a non-integer element to an intset should convert encoding
        setup_move
        assert_equal 1 [r smove myset1 myset2 a]
        assert_equal {1 b} [lsort [r smembers myset1]]
        assert_equal {2 3 4 a} [lsort [r smembers myset2]]
        #assert_encoding hashtable myset2

        # move an integer element should not convert the encoding
        setup_move
        assert_equal 1 [r smove myset1 myset2 1]
        assert_equal {a b} [lsort [r smembers myset1]]
        assert_equal {1 2 3 4} [lsort [r smembers myset2]]
        #assert_encoding intset myset2
    }

    test "SMOVE basics - from intset to regular set" {
        setup_move
        assert_equal 1 [r smove myset2 myset1 2]
        assert_equal {1 2 a b} [lsort [r smembers myset1]]
        assert_equal {3 4} [lsort [r smembers myset2]]
    }

    test "SMOVE non existing key" {
        setup_move
        assert_equal 0 [r smove myset1 myset2 foo]
        assert_equal 0 [r smove myset1 myset1 foo]
        assert_equal {1 a b} [lsort [r smembers myset1]]
        assert_equal {2 3 4} [lsort [r smembers myset2]]
    }

    test "SMOVE non existing src set" {
        setup_move
        assert_equal 0 [r smove noset myset2 foo]
        assert_equal {2 3 4} [lsort [r smembers myset2]]
    }

    test "SMOVE from regular set to non existing destination set" {
        setup_move
        assert_equal 1 [r smove myset1 myset3 a]
        assert_equal {1 b} [lsort [r smembers myset1]]
        assert_equal {a} [lsort [r smembers myset3]]
        #assert_encoding hashtable myset3
    }

    test "SMOVE from intset to non existing destination set" {
        setup_move
        assert_equal 1 [r smove myset2 myset3 2]
        assert_equal {3 4} [lsort [r smembers myset2]]
        assert_equal {2} [lsort [r smembers myset3]]
        #assert_encoding intset myset3
    }

    test "SMOVE wrong src key type" {
        r set x 10
        assert_error "*WRONGTYPE*" {r smove x myset2 foo}
    }

    test "SMOVE wrong dst key type" {
        r set str 10
        assert_error "*WRONGTYPE*" {r smove myset2 str foo}
    }

    test "SMOVE with identical source and destination" {
        r del set
        r sadd set a b c
        r smove set set b
        lsort [r smembers set]
    } {a b c}

    tags {slow} {
        test {intsets implementation stress testing} {
            for {set j 0} {$j < 20} {incr j} {
                unset -nocomplain s
                array set s {}
                r del s
                set len [randomInt 1024]
                for {set i 0} {$i < $len} {incr i} {
                    randpath {
                        set data [randomInt 65536]
                    } {
                        set data [randomInt 4294967296]
                    } {
                        set data [randomInt 18446744073709551616]
                    }
                    set s($data) {}
                    r sadd s $data
                }
                assert_equal [lsort [r smembers s]] [lsort [array names s]]
                set len [array size s]
                for {set i 0} {$i < $len} {incr i} {
                    set e [r spop s]
                    if {![info exists s($e)]} {
                        puts "Can't find '$e' on local array"
                        puts "Local array: [lsort [r smembers s]]"
                        puts "Remote array: [lsort [array names s]]"
                        error "exception"
                    }
                    array unset s $e
                }
                assert_equal [r scard s] 0
                assert_equal [array size s] 0
            }
        }
    }
}
