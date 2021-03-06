#  Copyright (C) 2003-2007 Tresys Technology, LLC
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA

namespace eval Apol_Analysis_domaintrans {
    variable vals
    variable widgets
    Apol_Analysis::registerAnalysis "Apol_Analysis_domaintrans" "Domain Transition"
}

proc Apol_Analysis_domaintrans::create {options_frame} {
    variable vals
    variable widgets

    _reinitializeVals

    set dir_tf [TitleFrame $options_frame.dir -text "Direction"]
    pack $dir_tf -side left -padx 2 -pady 2 -expand 0 -fill y
    set dir_forward [radiobutton [$dir_tf getframe].forward -text "Forward" \
                         -variable Apol_Analysis_domaintrans::vals(dir) \
                         -value $::APOL_DOMAIN_TRANS_DIRECTION_FORWARD]
    set dir_reverse [radiobutton [$dir_tf getframe].reverse -text "Reverse" \
                         -variable Apol_Analysis_domaintrans::vals(dir) \
                         -value $::APOL_DOMAIN_TRANS_DIRECTION_REVERSE]
    pack $dir_forward $dir_reverse -anchor w
    trace add variable Apol_Analysis_domaintrans::vals(dir) write \
        Apol_Analysis_domaintrans::_toggleDirection

    set req_tf [TitleFrame $options_frame.req -text "Required Parameters"]
    pack $req_tf -side left -padx 2 -pady 2 -expand 0 -fill y
    set l [label [$req_tf getframe].l -textvariable Apol_Analysis_domaintrans::vals(type:label)]
    pack $l -anchor w
    set widgets(type) [Apol_Widget::makeTypeCombobox [$req_tf getframe].type]
    pack $widgets(type)

    set filter_tf [TitleFrame $options_frame.filter -text "Optional Result Filters"]
    pack $filter_tf -side left -padx 2 -pady 2 -expand 1 -fill both
    set access_f [frame [$filter_tf getframe].access]
    pack $access_f -side left -anchor nw
    set widgets(access_enable) [checkbutton $access_f.enable -text "Use access filters" \
                                    -variable Apol_Analysis_domaintrans::vals(access:enable)]
    pack $widgets(access_enable) -anchor w
    set widgets(access) [button $access_f.b -text "Access Filters" \
                             -command Apol_Analysis_domaintrans::_createAccessDialog \
                             -state disabled]
    pack $widgets(access) -anchor w -padx 4
    trace add variable Apol_Analysis_domaintrans::vals(access:enable) write \
        Apol_Analysis_domaintrans::_toggleAccessSelected
    set widgets(regexp) [Apol_Widget::makeRegexpEntry [$filter_tf getframe].end]
    $widgets(regexp).cb configure -text "Filter result types using regular expression"
    pack $widgets(regexp) -side left -anchor nw -padx 8
}

proc Apol_Analysis_domaintrans::open {} {
    variable vals
    variable widgets
    Apol_Widget::resetTypeComboboxToPolicy $widgets(type)
    set vals(targets:inc) [Apol_Types::getTypes]
    set vals(targets:inc_displayed) [Apol_Types::getTypes]
    foreach c [Apol_Class_Perms::getClasses] {
        set vals(classes:$c) [Apol_Class_Perms::getPermsForClass $c]
        set vals(classes:$c:enable) 1
    }
}

proc Apol_Analysis_domaintrans::close {} {
    variable widgets
    _reinitializeVals
    _reinitializeWidgets
    Apol_Widget::clearTypeCombobox $widgets(type)
}

proc Apol_Analysis_domaintrans::getInfo {} {
    return "A forward domain transition analysis will determine all (target)
domains to which a given (source) domain may transition.  For a
forward domain transition to be allowed, multiple forms of access must
be granted:

\n    (1) source domain must have process transition permission for
        target domain,
    (2) source domain must have file execute permission for some
        entrypoint type,
    (3) target domain must have file entrypoint permission for the
        same entrypoint type, and,
    (4) for policies version 15 or later, either a type_transition
        rule or a setexec permission for the source domain.

\nA reverse domain transition analysis will determine all (source)
domains that can transition to a given (target) domain.  For a reverse
domain transition to be allowed, three forms of access must be
granted:

\n    (1) target domain must have process transition permission from the
        source domain,
    (2) target domain must have file entrypoint permission to some
        entrypoint type, and
    (3) source domain must have file execute permission to the same
        entrypoint type.

\nThe results are presented in tree form.  Open target children domains
to perform another domain transition analysis on that domain.

\nFor additional help on this topic select \"Domain Transition Analysis\"
from the Help menu."
}

proc Apol_Analysis_domaintrans::newAnalysis {} {
    if {[set rt [_checkParams]] != {}} {
        return $rt
    }
    set results [_analyze]
    set f [_createResultsDisplay]
    _renderResults $f $results
    $results -acquire
    $results -delete
    return {}
}

proc Apol_Analysis_domaintrans::updateAnalysis {f} {
    variable vals

    if {[set rt [_checkParams]] != {}} {
        return $rt
    }

    if {$vals(dir) == $::APOL_DOMAIN_TRANS_DIRECTION_FORWARD} {
        $f.left configure -text "Forward Domain Transition"
    } else {
        $f.left configure -text "Reverse Domain Transition"
    }

    set results [_analyze]
    _clearResultsDisplay $f
    _renderResults $f $results
    $results -acquire
    $results -delete
    return {}
}

proc Apol_Analysis_domaintrans::reset {} {
    _reinitializeVals
    _reinitializeWidgets
}

proc Apol_Analysis_domaintrans::switchTab {query_options} {
    variable vals
    variable widgets
    array set vals $query_options
    if {$vals(type:attrib) != {}} {
        Apol_Widget::setTypeComboboxValue $widgets(type) [list $vals(type) $vals(type:attrib)]
    } else {
        Apol_Widget::setTypeComboboxValue $widgets(type) $vals(type)
    }
    Apol_Widget::setRegexpEntryValue $widgets(regexp) $vals(regexp:enable) $vals(regexp)
}

proc Apol_Analysis_domaintrans::saveQuery {channel} {
    variable vals
    variable widgets
    foreach {key value} [array get vals] {
        switch -- $key {
            targets:inc_displayed -
            classes:perms_displayed -
            search:regexp -
            search:object_types -
            search:classperm_perms {
                # don't save these variables
            }
            default {
                puts $channel "$key $value"
            }
        }
    }
    set type [Apol_Widget::getTypeComboboxValueAndAttrib $widgets(type)]
    puts $channel "type [lindex $type 0]"
    puts $channel "type:attrib [lindex $type 1]"
    set use_regexp [Apol_Widget::getRegexpEntryState $widgets(regexp)]
    set regexp [Apol_Widget::getRegexpEntryValue $widgets(regexp)]
    puts $channel "regexp:enable $use_regexp"
    puts $channel "regexp $regexp"
}

proc Apol_Analysis_domaintrans::loadQuery {channel} {
    variable vals
    set targets_inc {}
    while {[gets $channel line] >= 0} {
        set line [string trim $line]
        # Skip empty lines and comments
        if {$line == {} || [string index $line 0] == "#"} {
            continue
        }
        set key {}
        set value {}
        regexp -line -- {^(\S+)( (.+))?} $line -> key --> value
        if {$key == "targets:inc"} {
            lappend targets_inc $value
        } elseif {[regexp -- {^classes:(.+)} $key -> class]} {
            set c($class) $value
        } else {
            set vals($key) $value
        }
    }

    # fill in the inclusion lists using only types/classes found
    # within the current policy
    open

    set vals(targets:inc) {}
    foreach s $targets_inc {
        set i [lsearch [Apol_Types::getTypes] $s]
        if {$i >= 0} {
            lappend vals(targets:inc) $s
        }
    }

    foreach class_key [array names c] {
        if {[regexp -- {^([^:]+):enable} $class_key -> class]} {
            if {[lsearch [Apol_Class_Perms::getClasses] $class] >= 0} {
                set vals(classes:$class:enable) $c($class_key)
            }
        } else {
            set class $class_key
            set old_p $vals(classes:$class)
            set new_p {}
            foreach p $c($class) {
                if {[lsearch $old_p $p] >= 0} {
                    lappend new_p $p
                }
            }
            set vals(classes:$class) [lsort -uniq $new_p]
        }
    }
    _reinitializeWidgets
}

proc Apol_Analysis_domaintrans::getTextWidget {tab} {
    return [$tab.right getframe].res.tb
}

proc Apol_Analysis_domaintrans::appendResultsNodes {tree parent_node results} {
    _createResultsNodes $tree $parent_node $results $::APOL_DOMAIN_TRANS_DIRECTION_FORWARD
}

#################### private functions below ####################

proc Apol_Analysis_domaintrans::_reinitializeVals {} {
    variable vals

    set vals(dir) $::APOL_DOMAIN_TRANS_DIRECTION_FORWARD
    array set vals {
        type:label "Source domain"
        type {}  type:attrib {}

        regexp:enable 0
        regexp {}

        access:enable 0
        targets:inc {}   targets:inc_displayed {}
        targets:attribenable 0  targets:attrb {}
    }
    array unset vals classes:*
    array unset vals search:*
    foreach c [Apol_Class_Perms::getClasses] {
        set vals(classes:$c) [Apol_Class_Perms::getPermsForClass $c]
        set vals(classes:$c:enable) 1
    }
}

proc Apol_Analysis_domaintrans::_reinitializeWidgets {} {
    variable vals
    variable widgets

    if {$vals(type:attrib) != {}} {
        Apol_Widget::setTypeComboboxValue $widgets(type) [list $vals(type) $vals(type:attrib)]
    } else {
        Apol_Widget::setTypeComboboxValue $widgets(type) $vals(type)
    }
    Apol_Widget::setRegexpEntryValue $widgets(regexp) $vals(regexp:enable) $vals(regexp)
}

proc Apol_Analysis_domaintrans::_toggleDirection {name1 name2 op} {
    variable vals
    if {$vals(dir) == $::APOL_DOMAIN_TRANS_DIRECTION_FORWARD} {
        set vals(type:label) "Source domain"
    } else {
        set vals(type:label) "Target domain"
    }
    _maybeEnableAccess
}

proc Apol_Analysis_domaintrans::_toggleAccessSelected {name1 name2 op} {
    _maybeEnableAccess
}

proc Apol_Analysis_domaintrans::_maybeEnableAccess {} {
    variable vals
    variable widgets
    if {$vals(dir) == $::APOL_DOMAIN_TRANS_DIRECTION_FORWARD} {
        $widgets(access_enable) configure -state normal
        if {$vals(access:enable)} {
            $widgets(access) configure -state normal
        } else {
            $widgets(access) configure -state disabled
        }
    } else {
        $widgets(access_enable) configure -state disabled
        $widgets(access) configure -state disabled
    }
}

################# functions that do access filters #################

proc Apol_Analysis_domaintrans::_createAccessDialog {} {
    variable widgets
    $widgets(access) configure -state disabled
    destroy .domaintrans_adv
    set d [Dialog .domaintrans_adv -modal local -separator 1 -title "Domain Transition Access Filter" -parent .]
    $d add -text "Close"
    _createAccessTargets [$d getframe]
    _createAccessClasses [$d getframe]
    $d draw
    $widgets(access) configure -state normal
}

proc Apol_Analysis_domaintrans::_createAccessTargets {f} {
    variable vals

    set type_f [frame $f.targets]
    pack $type_f -side left -expand 0 -fill both -padx 4 -pady 4
    set l1 [label $type_f.l1 -text "Included Object Types"]
    pack $l1 -anchor w

    set targets [Apol_Widget::makeScrolledListbox $type_f.targets -height 10 -width 24 \
                 -listvar Apol_Analysis_domaintrans::vals(targets:inc_displayed) \
                 -selectmode extended -exportselection 0]
    set targets_lb [Apol_Widget::getScrolledListbox $targets]
    bind $targets_lb <<ListboxSelect>> \
        [list Apol_Analysis_domaintrans::_selectTargetListbox $targets_lb]
    pack $targets -expand 0 -fill both

    set bb [ButtonBox $type_f.bb -homogeneous 1 -spacing 4]
    $bb add -text "Include All" \
        -command [list Apol_Analysis_domaintrans::_includeAllItems $targets_lb targets]
    $bb add -text "Ignore All" \
        -command [list Apol_Analysis_domaintrans::_ignoreAllItems $targets_lb targets]
    pack $bb -pady 4

    set attrib [frame $type_f.a]
    pack $attrib
    set attrib_enable [checkbutton $attrib.ae -anchor w \
                           -text "Filter by attribute" \
                           -variable Apol_Analysis_domaintrans::vals(targets:attribenable)]
    set attrib_box [ComboBox $attrib.ab -autopost 1 -entrybg white -width 16 \
                        -values $Apol_Types::attriblist \
                        -textvariable Apol_Analysis_domaintrans::vals(targets:attrib)]
    $attrib_enable configure -command \
        [list Apol_Analysis_domaintrans::_attribEnabled $attrib_box $targets_lb]
    # remove any old traces on the attribute
    trace remove variable Apol_Analysis_domaintrans::vals(targets:attrib) write \
        [list Apol_Analysis_domaintrans::_attribChanged $targets_lb]
    trace add variable Apol_Analysis_domaintrans::vals(targets:attrib) write \
        [list Apol_Analysis_domaintrans::_attribChanged $targets_lb]
    pack $attrib_enable -side top -expand 0 -fill x -anchor sw -padx 5 -pady 2
    pack $attrib_box -side top -expand 1 -fill x -padx 10
    _attribEnabled $attrib_box $targets_lb
    if {[set anchor [lindex [lsort [$targets_lb curselection]] 0]] != {}} {
        $targets_lb selection anchor $anchor
        $targets_lb see $anchor
    }
}

proc Apol_Analysis_domaintrans::_selectTargetListbox {lb} {
    variable vals
    for {set i 0} {$i < [$lb index end]} {incr i} {
        set t [$lb get $i]
        if {[$lb selection includes $i]} {
            lappend vals(targets:inc) $t
        } else {
            if {[set j [lsearch $vals(targets:inc) $t]] >= 0} {
                set vals(targets:inc) [lreplace $vals(targets:inc) $j $j]
            }
        }
    }
    set vals(targets:inc) [lsort -uniq $vals(targets:inc)]
    focus $lb
}

proc Apol_Analysis_domaintrans::_includeAllItems {lb varname} {
    variable vals
    $lb selection set 0 end
    set displayed [$lb get 0 end]
    set vals($varname:inc) [lsort -uniq [concat $vals($varname:inc) $displayed]]
}

proc Apol_Analysis_domaintrans::_ignoreAllItems {lb varname} {
    variable vals
    $lb selection clear 0 end
    set displayed [$lb get 0 end]
    set inc {}
    foreach t $vals($varname:inc) {
        if {[lsearch $displayed $t] == -1} {
            lappend inc $t
        }
    }
    set vals($varname:inc) $inc
}

proc Apol_Analysis_domaintrans::_attribEnabled {cb lb} {
    variable vals
    if {$vals(targets:attribenable)} {
        $cb configure -state normal
        _filterTypeLists $vals(targets:attrib) $lb
    } else {
        $cb configure -state disabled
        _filterTypeLists "" $lb
    }
}

proc Apol_Analysis_domaintrans::_attribChanged {lb name1 name2 op} {
    variable vals
    if {$vals(targets:attribenable)} {
        _filterTypeLists $vals(targets:attrib) $lb
    }
}

proc Apol_Analysis_domaintrans::_filterTypeLists {attrib lb} {
    variable vals
    $lb selection clear 0 end
    if {$attrib != ""} {
        set vals(targets:inc_displayed) {}
        set qpol_type_datum [new_qpol_type_t $::ApolTop::qpolicy $attrib]
        set i [$qpol_type_datum get_type_iter $::ApolTop::qpolicy]
        while {![$i end]} {
            set t [qpol_type_from_void [$i get_item]]
            lappend vals(targets:inc_displayed) [$t get_name $::ApolTop::qpolicy]
            $i next
        }
        $i -acquire
        $i -delete
        set vals(targets:inc_displayed) [lsort $vals(targets:inc_displayed)]
    } else {
        set vals(targets:inc_displayed) [Apol_Types::getTypes]
    }
    foreach t $vals(targets:inc) {
        if {[set i [lsearch $vals(targets:inc_displayed) $t]] >= 0} {
            $lb selection set $i $i
        }
    }
}

proc Apol_Analysis_domaintrans::_createAccessClasses {f} {
    variable vals
    variable widgets

    set lf [frame $f.left]
    pack $lf -side left -expand 0 -fill both -padx 4 -pady 4
    set l1 [label $lf.l -text "Included Object Classes"]
    pack $l1 -anchor w
    set rf [frame $f.right]
    pack $rf -side left -expand 0 -fill both -padx 4 -pady 4
    set l2 [label $rf.l]
    pack $l2 -anchor w

    set vals(classes:all_classes) [Apol_Class_Perms::getClasses]
    set classes [Apol_Widget::makeScrolledListbox $lf.classes -height 10 -width 24 \
                     -listvar Apol_Analysis_domaintrans::vals(classes:all_classes) \
                     -selectmode extended -exportselection 0]
    set classes_lb [Apol_Widget::getScrolledListbox $classes]
    pack $classes -expand 1 -fill both
    set cbb [ButtonBox $lf.cbb -homogeneous 1 -spacing 4]
    $cbb add -text "Include All" \
        -command [list Apol_Analysis_domaintrans::_includeAllClasses $classes_lb]
    $cbb add -text "Ignore All" \
        -command [list Apol_Analysis_domaintrans::_ignoreAllClasses $classes_lb]
    pack $cbb -pady 4 -expand 0

    set perms [Apol_Widget::makeScrolledListbox $rf.perms -height 10 -width 24 \
                     -listvar Apol_Analysis_domaintrans::vals(classes:perms_displayed) \
                     -selectmode extended -exportselection 0]
    set perms_lb [Apol_Widget::getScrolledListbox $perms]
    pack $perms -expand 1 -fill both
    set pbb [ButtonBox $rf.pbb -homogeneous 1 -spacing 4]
    $pbb add -text "Include All" \
        -command [list Apol_Analysis_domaintrans::_includeAllPerms $classes_lb $perms_lb]
    $pbb add -text "Ignore All" \
        -command [list Apol_Analysis_domaintrans::_ignoreAllPerms $classes_lb $perms_lb]
    pack $pbb -pady 4 -expand 0

    bind $classes_lb <<ListboxSelect>> \
        [list Apol_Analysis_domaintrans::_selectClassListbox $l2 $classes_lb $perms_lb]
    bind $perms_lb <<ListboxSelect>> \
        [list Apol_Analysis_domaintrans::_selectPermListbox $classes_lb $perms_lb]

    foreach class_key [array names vals classes:*:enable] {
        if {$vals($class_key)} {
            regexp -- {^classes:([^:]+):enable} $class_key -> class
            set i [lsearch [Apol_Class_Perms::getClasses] $class]
            $classes_lb selection set $i $i
        }
    }
    if {[set anchor [lindex [lsort [$classes_lb curselection]] 0]] != {}} {
        $classes_lb selection anchor $anchor
        $classes_lb see $anchor
    }
    set vals(classes:perms_displayed) {}
    _selectClassListbox $l2 $classes_lb $perms_lb
}

proc Apol_Analysis_domaintrans::_selectClassListbox {perm_label lb plb} {
    variable vals
    for {set i 0} {$i < [$lb index end]} {incr i} {
        set c [$lb get $i]
        set vals(classes:$c:enable) [$lb selection includes $i]
    }
    if {[set class [$lb get anchor]] == {}} {
        $perm_label configure -text "Permissions"
        return
    }

    $perm_label configure -text "Permissions for $class"
    set vals(classes:perms_displayed) [Apol_Class_Perms::getPermsForClass $class]
    $plb selection clear 0 end
    foreach p $vals(classes:$class) {
        set i [lsearch $vals(classes:perms_displayed) $p]
        $plb selection set $i
    }
    if {[set anchor [lindex [lsort [$plb curselection]] 0]] != {}} {
        $plb selection anchor $anchor
        $plb see $anchor
    }
    focus $lb
}

proc Apol_Analysis_domaintrans::_includeAllClasses {lb} {
    variable vals
    $lb selection set 0 end
    foreach c [Apol_Class_Perms::getClasses] {
        set vals(classes:$c:enable) 1
    }
}

proc Apol_Analysis_domaintrans::_ignoreAllClasses {lb} {
    variable vals
    $lb selection clear 0 end
    foreach c [Apol_Class_Perms::getClasses] {
        set vals(classes:$c:enable) 0
    }
}

proc Apol_Analysis_domaintrans::_selectPermListbox {lb plb} {
    variable vals
    set class [$lb get anchor]
    set p {}
    foreach i [$plb curselection] {
        lappend p [$plb get $i]
    }
    set vals(classes:$class) $p
    focus $plb
}

proc Apol_Analysis_domaintrans::_includeAllPerms {lb plb} {
    variable vals
    set class [$lb get anchor]
    $plb selection set 0 end
    set vals(classes:$class) $vals(classes:perms_displayed)
}

proc Apol_Analysis_domaintrans::_ignoreAllPerms {lb plb} {
    variable vals
    set class [$lb get anchor]
    $plb selection clear 0 end
    set vals(classes:$class) {}
}

#################### functions that do analyses ####################

proc Apol_Analysis_domaintrans::_checkParams {} {
    variable vals
    variable widgets
    if {![ApolTop::is_policy_open]} {
        return "No current policy file is opened."
    }
    set type [Apol_Widget::getTypeComboboxValueAndAttrib $widgets(type)]
    if {[lindex $type 0] == {}} {
        return "No type was selected."
    }
    if {![Apol_Types::isTypeInPolicy [lindex $type 0]]} {
        return "[lindex $type 0] is not a type within the policy."
    }
    set vals(type) [lindex $type 0]
    set vals(type:attrib) [lindex $type 1]
    set use_regexp [Apol_Widget::getRegexpEntryState $widgets(regexp)]
    set regexp [Apol_Widget::getRegexpEntryValue $widgets(regexp)]
    if {$use_regexp && $regexp == {}} {
            return "No regular expression provided."
    }
    set vals(regexp:enable) $use_regexp
    set vals(regexp) $regexp
    if {$vals(dir) == $::APOL_DOMAIN_TRANS_DIRECTION_FORWARD && $vals(access:enable)} {
        set classperm_pairs {}
        foreach class [Apol_Class_Perms::getClasses] {
            if {$vals(classes:$class:enable) == 0} {
                continue
            }
            if {$vals(classes:$class) == {}} {
                return "No permissions were selected for class $class."
            }
            foreach perm $vals(classes:$class) {
                lappend classperm_pairs [list $class $perm]
            }
        }
        if {$vals(targets:inc) == {}} {
            return "No object types were selected."
        }
        if {$classperm_pairs == {}} {
            return "No object classes were selected."
        }
        set vals(search:object_types) $vals(targets:inc)
        set vals(search:classperm_pairs) $classperm_pairs
    } else {
        set vals(search:object_types) {}
        set vals(search:classperm_pairs) {}
    }
    if {$vals(regexp:enable)} {
        set vals(search:regexp) $vals(regexp)
    } else {
        set vals(search:regexp) {}
    }
    return {}  ;# all parameters passed, now ready to do search
}

proc Apol_Analysis_domaintrans::_analyze {} {
    variable vals
    $::ApolTop::policy reset_domain_trans_table
    set q [new_apol_domain_trans_analysis_t]
    $q set_direction $::ApolTop::policy $vals(dir)
    $q set_start_type $::ApolTop::policy $vals(type)
    $q set_result_regex $::ApolTop::policy $vals(search:regexp)
    foreach o $vals(search:object_types) {
        $q append_access_type $::ApolTop::policy $o
    }
    foreach {cp_pair} $vals(search:classperm_pairs) {
        $q append_class $::ApolTop::policy [lindex $cp_pair 0]
        $q append_perm $::ApolTop::policy [lindex $cp_pair 1]
    }
    apol_tcl_set_info_string $::ApolTop::policy "Building domain transition table..."
    $::ApolTop::policy build_domain_trans_table
    apol_tcl_set_info_string $::ApolTop::policy "Performing Domain Transition Analysis..."
    set v [$q run $::ApolTop::policy]
    $q -acquire
    $q -delete
    return $v
}

proc Apol_Analysis_domaintrans::_analyzeMore {tree node analysis_args} {
    # disallow more analysis if this node is the same as its parent
    set new_start [$tree itemcget $node -text]
    if {[$tree itemcget [$tree parent $node] -text] == $new_start} {
        return {}
    }
    foreach {dir orig_type object_types classperm_pairs regexp} $analysis_args {break}
    set q [new_apol_domain_trans_analysis_t]
    $q set_direction $::ApolTop::policy $dir
    $q set_start_type $::ApolTop::policy $new_start
    $q set_result_regex $::ApolTop::policy $regexp
    foreach o $object_types {
        $q append_access_type $::ApolTop::policy $o
    }
    foreach {cp_pair} $classperm_pairs {
        $q append_class $::ApolTop::policy [lindex $cp_pair 0]
        $q append_perm $::ApolTop::policy [lindex $cp_pair 1]
    }
    $::ApolTop::policy reset_domain_trans_table
    set v [$q run $::ApolTop::policy]
    $q -acquire
    $q -delete
    return $v
}

################# functions that control analysis output #################

proc Apol_Analysis_domaintrans::_createResultsDisplay {} {
    variable vals

    set f [Apol_Analysis::createResultTab "Domain Trans" [array get vals]]
    if {$vals(dir) == $::APOL_DOMAIN_TRANS_DIRECTION_FORWARD} {
        set tree_title "Forward Domain Transition"
    } else {
        set tree_title "Reverse Domain Transition"
    }
    set tree_tf [TitleFrame $f.left -text $tree_title]
    pack $tree_tf -side left -expand 0 -fill y -padx 2 -pady 2
    set sw [ScrolledWindow [$tree_tf getframe].sw -auto both]
    set tree [Tree [$sw getframe].tree -width 24 -redraw 1 -borderwidth 0 \
                  -highlightthickness 0 -showlines 1 -padx 0 -bg white]
    $sw setwidget $tree
    pack $sw -expand 1 -fill both

    set res_tf [TitleFrame $f.right -text "Domain Transition Results"]
    pack $res_tf -side left -expand 1 -fill both -padx 2 -pady 2
    set res [Apol_Widget::makeSearchResults [$res_tf getframe].res]
    $res.tb tag configure title -font {Helvetica 14 bold}
    $res.tb tag configure title_type -foreground blue -font {Helvetica 14 bold}
    $res.tb tag configure subtitle -font {Helvetica 10 bold}
    $res.tb tag configure num -foreground blue -font {Helvetica 10 bold}
    pack $res -expand 1 -fill both

    $tree configure -selectcommand [list Apol_Analysis_domaintrans::_treeSelect $res]
    $tree configure -opencmd [list Apol_Analysis_domaintrans::_treeOpen $tree]
    return $f
}

proc Apol_Analysis_domaintrans::_treeSelect {res tree node} {
    if {$node != {}} {
        $res.tb configure -state normal
        $res.tb delete 0.0 end
        set data [$tree itemcget $node -data]
        if {[string index $node 0] == "f" || [string index $node 0] == "r"} {
            _renderResultsDTA $res $tree $node [lindex $data 1]
        } else {
            # an informational node, whose data has already been rendered
            eval $res.tb insert end $data
        }
        $res.tb configure -state disabled
    }
}

# perform additional domain transitions if this node has not been
# analyzed yet
proc Apol_Analysis_domaintrans::_treeOpen {tree node} {
    foreach {search_crit results} [$tree itemcget $node -data] {break}
    if {([string index $node 0] == "f" || [string index $node 0] == "r") && $search_crit != {}} {
        set new_results [Apol_Progress_Dialog::wait "Domain Transition Analysis" \
                             "Performing Domain Transition Analysis..." \
                             { _analyzeMore $tree $node $search_crit }]
        # mark this node as having been expanded
        $tree itemconfigure $node -data [list {} $results]
        if {$new_results != {}} {
            _createResultsNodes $tree $node $new_results $search_crit
            $new_results -acquire
            $new_results -delete
        }
    }
}

proc Apol_Analysis_domaintrans::_clearResultsDisplay {f} {
    variable vals
    set tree [[$f.left getframe].sw getframe].tree
    set res [$f.right getframe].res
    $tree delete [$tree nodes root]
    Apol_Widget::clearSearchResults $res
    Apol_Analysis::setResultTabCriteria [array get vals]
}

proc Apol_Analysis_domaintrans::_renderResults {f results} {
    variable vals

    set tree [[$f.left getframe].sw getframe].tree
    set res [$f.right getframe].res

    $tree insert end root top -text $vals(type) -open 1 -drawcross auto
    set top_text [_renderTopText]
    $tree itemconfigure top -data $top_text

    set search_crit [list $vals(dir) $vals(type) $vals(search:object_types) $vals(search:classperm_pairs) $vals(search:regexp)]
    _createResultsNodes $tree top $results $search_crit
    $tree selection set top
    $tree opentree top 0
    $tree see top
}

proc Apol_Analysis_domaintrans::_renderTopText {} {
    variable vals

    if {$vals(dir) == $::APOL_DOMAIN_TRANS_DIRECTION_FORWARD} {
        set top_text [list "Forward Domain Transition Analysis: Starting Type: " title]
    } else {
        set top_text [list "Reverse Domain Transition Analysis: Starting Type: " title]
    }
    lappend top_text $vals(type) title_type \
        "\n\n" title
    if {$vals(dir) == $::APOL_DOMAIN_TRANS_DIRECTION_FORWARD} {
        lappend top_text \
"This tab provides the results of a forward domain transition analysis
starting from the source domain type above.  The results of this
analysis are presented in tree form with the root of the tree (this
node) being the start point for the analysis.

\nEach child node in the tree represents a TARGET DOMAIN TYPE.  A target
domain type is a domain to which the source domain may transition.
You can follow the domain transition tree by opening each subsequent
generation of children in the tree.\n" {}
    } else {
        lappend top_text \
"This tab provides the results of a reverse domain transition analysis
given the target domain type above.  The results of this analysis are
presented in tree form with the root of the tree (this node) being the
target point of the analysis.

\nEach child node in the tree represents a source DOMAIN TYPE.  A source
domain type is a domain that can transition to the target domain.  You
can follow the domain transition tree by opening each subsequent
generation of children in the tree.\n" {}
    }
    lappend top_text \
"\nNOTE: For any given generation, if the parent and the child are the
same, you cannot open the child. This avoids cyclic analyses.

\nThe criteria that defines an allowed domain transition are:

\n1) There must be at least one rule that allows TRANSITION access for
   PROCESS objects between the SOURCE and TARGET domain types.

\n2) There must be at least one FILE TYPE that allows the TARGET type
   ENTRYPOINT access for FILE objects.

\n3) There must be at least one FILE TYPE that meets criterion 2) above
   and allows the SOURCE type EXECUTE access for FILE objects.

\n4) For modular policies and monolithic policies greater than version
   15, there must also be at least one of the following:
   a) A type_transition rule for class PROCESS from SOURCE to TARGET
      for FILE TYPE, or
   b) A rule that allows SETEXEC for SOURCE to itself.

\nThe information window shows all the rules and file types that meet
these criteria for each target domain type." {}
}

proc Apol_Analysis_domaintrans::_createResultsNodes {tree parent_node results search_crit} {
    set dir [lindex $search_crit 0]
    set dt_list [domain_trans_result_vector_to_list $results]
    set results_processed 0
    foreach r $dt_list {
        apol_tcl_set_info_string $::ApolTop::policy "Processing result $results_processed of [llength $dt_list]"
        set source [[$r get_start_type] get_name $::ApolTop::qpolicy]
        set target [[$r get_end_type] get_name $::ApolTop::qpolicy]
        set intermed [[$r get_entrypoint_type] get_name $::ApolTop::qpolicy]
        set proctrans [avrule_vector_to_list [$r get_proc_trans_rules]]
        set entrypoint [avrule_vector_to_list [$r get_entrypoint_rules]]
        set execute [avrule_vector_to_list [$r get_exec_rules]]
        set setexec [avrule_vector_to_list [$r get_setexec_rules]]
        set type_trans [terule_vector_to_list [$r get_type_trans_rules]]
        set access_list [avrule_vector_to_list [$r get_access_rules]]
        if {$dir == $::APOL_DOMAIN_TRANS_DIRECTION_FORWARD} {
            set key $target
            set node f:\#auto
        } else {
            set key $source
            set node r:\#auto
        }
        foreach p $proctrans {
            lappend types($key) $p
        }
        if {[info exists types($key:setexec)]} {
            set types($key:setexec) [concat $types($key:setexec) $setexec]
        } else {
            set types($key:setexec) $setexec
        }
        lappend types($key:inter) $intermed
        foreach e $entrypoint {
            lappend types($key:inter:$intermed:entry) $e
        }
        foreach e $execute {
            lappend types($key:inter:$intermed:exec) $e
        }
        if {[info exists types($key:inter:$intermed:type_trans)]} {
            set types($key:inter:$intermed:type_trans) [concat $types($key:inter:$intermed:type_trans) $type_trans]
        } else {
            set types($key:inter:$intermed:type_trans) $type_trans
        }
        if {[info exists types($key:access)]} {
            set types($key:access) [concat $types($key:access) $access_list]
        } else {
            set types($key:access) $access_list
        }
        incr results_processed
    }
    foreach key [lsort [array names types]] {
        if {[string first : $key] != -1} {
            continue
        }
        set ep {}
        set proctrans [lsort -uniq $types($key)]
        set setexec [lsort -uniq $types($key:setexec)]
        foreach intermed [lsort -uniq $types($key:inter)] {
            lappend ep [list $intermed \
                            [lsort -uniq $types($key:inter:$intermed:entry)] \
                            [lsort -uniq $types($key:inter:$intermed:exec)] \
                            [lsort -uniq $types($key:inter:$intermed:type_trans)]]
        }
        set access_list [lsort -uniq $types($key:access)]
        set data [list $proctrans $setexec $ep $access_list]
        $tree insert end $parent_node $node -text $key -drawcross allways \
            -data [list $search_crit $data]
    }
}

proc Apol_Analysis_domaintrans::_renderResultsDTA {res tree node data} {
    set parent_name [$tree itemcget [$tree parent $node] -text]
    set name [$tree itemcget $node -text]
    foreach {proctrans setexec ep access_list} $data {break}
    # direction of domain transition is encoded encoded in the node's
    # identifier
    if {[string index $node 0] == "f"} {
        set header [list "Domain transition from " title \
                        $parent_name title_type \
                        " to " title \
                        $name title_type]
    } else {
        set header [list "Domain transition from " title \
                        $name title_type \
                        " to " title \
                        $parent_name title_type]
    }
    eval $res.tb insert end $header
    $res.tb insert end "\n\n" title_type

    $res.tb insert end "Process Transition Rules: " subtitle \
        [llength $proctrans] num \
        "\n" subtitle
    set v [list_to_vector $proctrans]
    apol_tcl_avrule_sort $::ApolTop::policy $v
    Apol_Widget::appendSearchResultRules $res 6 $v qpol_avrule_from_void
    $v -acquire
    $v -delete
    if {[llength $setexec] > 0} {
        $res.tb insert end "\n" {} \
            "Setexec Rules: " subtitle \
            [llength $setexec] num \
            "\n" subtitle
        set v [list_to_vector $setexec]
        apol_tcl_avrule_sort $::ApolTop::policy $v
        Apol_Widget::appendSearchResultRules $res 6 $v qpol_avrule_from_void
        $v -acquire
        $v -delete
    }

    $res.tb insert end "\nEntry Point File Types: " subtitle \
        [llength $ep] num
    foreach e [lsort -index 0 $ep] {
        foreach {intermed entrypoint execute type_trans} $e {break}
        $res.tb insert end "\n      $intermed\n" {} \
            "            " {} \
            "File Entrypoint Rules: " subtitle \
            [llength $entrypoint] num \
            "\n" subtitle
        set v [list_to_vector $entrypoint]
        apol_tcl_avrule_sort $::ApolTop::policy $v
        Apol_Widget::appendSearchResultRules $res 12 $v qpol_avrule_from_void
        $v -acquire
        $v -delete
        $res.tb insert end "\n" {} \
            "            " {} \
            "File Execute Rules: " subtitle \
            [llength $execute] num \
            "\n" subtitle
        set v [list_to_vector $execute]
        apol_tcl_avrule_sort $::ApolTop::policy $v
        Apol_Widget::appendSearchResultRules $res 12 $v qpol_avrule_from_void
        $v -acquire
        $v -delete
        if {[llength $type_trans] > 0} {
            $res.tb insert end "\n" {} \
                "            " {} \
                "Type_transition Rules: " subtitle \
                [llength $type_trans] num \
                "\n" subtitle
            set v [list_to_vector $type_trans]
            apol_tcl_terule_sort $::ApolTop::policy $v
            Apol_Widget::appendSearchResultRules $res 12 $v qpol_terule_from_void
            $v -acquire
            $v -delete
        }
    }

    if {[llength $access_list] > 0} {
        $res.tb insert end "\n" {} \
            "The access filters you specified returned the following rules: " subtitle \
            [llength $access_list] num \
            "\n" subtitle
        set v [list_to_vector $access_list]
        apol_tcl_avrule_sort $::ApolTop::policy $v
        Apol_Widget::appendSearchResultRules $res 6 $v qpol_avrule_from_void
        $v -acquire
        $v -delete
    }
}
