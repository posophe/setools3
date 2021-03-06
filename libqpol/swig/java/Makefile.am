wrappedso_DATA = libjqpol.so.@libqpol_version@
wrappedso_SONAME = @libqpol_jswig_soname@
short_name = libjqpol.so
wrappedsodir = $(libdir)

package_name = com.tresys.setools.qpol
package_dir = $(dir $(subst .,/,$(package_name)))qpol

wrappedjar_DATA = qpol.jar
wrappedjardir = $(setoolsdir)

dist_noinst_DATA = $(srcdir)/../qpol.i
BUILT_SOURCES = qpol_wrap.c \
	qpol_avrule_t.java \
	qpol_bool_t.java \
	qpol_capability_e.java \
	qpol_cat_t.java \
	qpol_class_t.java \
	qpol_common_t.java \
	qpol_cond_expr_node_t.java \
	qpol_cond_t.java \
	qpolConstants.java \
	qpol_constraint_expr_node_t.java \
	qpol_constraint_t.java \
	qpol_context_t.java \
	qpol_fs_use_t.java \
	qpol_genfscon_t.java \
	qpol_isid_t.java \
	qpol_iterator_t.java \
	qpol.java \
	qpolJNI.java \
	qpol_level_t.java \
	qpol_mls_level_t.java \
	qpol_mls_range_t.java \
	qpol_module_t.java \
	qpol_netifcon_t.java \
	qpol_nodecon_t.java \
	qpol_policy_t.java \
	qpol_portcon_t.java \
	qpol_range_trans_t.java \
	qpol_role_allow_t.java \
	qpol_role_t.java \
	qpol_role_trans_t.java \
	qpol_syn_avrule_t.java \
	qpol_syn_terule_t.java \
	qpol_terule_t.java \
	qpol_type_set_t.java \
	qpol_type_t.java \
	qpol_user_t.java \
	qpol_validatetrans_t.java \
	SWIGTYPE_p_int.java \
	SWIGTYPE_p_unsigned_int.java \
	SWIGTYPE_p_void.java

AM_CFLAGS = @DEBUGCFLAGS@ @WARNCFLAGS@ @PROFILECFLAGS@ @SELINUX_CFLAGS@ \
	-I$(top_builddir) -fpic \
	-I$(top_srcdir)/libqpol/include
AM_JFLAGS = @DEBUGJFLAGS@ @WARNJFLAGS@
AM_LDFLAGS = @DEBUGLDFLAGS@ @WARNLDFLAGS@ @PROFILELDFLAGS@ @QPOL_LIB_FLAG@

$(firstword $(BUILT_SOURCES)): $(dist_noinst_DATA) $(DEPENDENCIES)
	$(SWIG) $(SWIG_JAVA_OPT) -package $(package_name) -o $@ -I$(top_srcdir)/libqpol/include $<

$(wordlist 2,$(words $(BUILT_SOURCES)), $(BUILT_SOURCES)): $(firstword $(BUILT_SOURCES))

$(wrappedso_DATA): $(filter %.c, $(BUILT_SOURCES))
	$(CC) -shared -o $@ $^ $(AM_CFLAGS) $(CFLAGS) $(SWIG_JAVA_CFLAGS) $(AM_LDFLAGS) $(LDFLAGS) -Wl,-soname,$(wrappedso_SONAME)
	$(LN_S) -f $@ $(wrappedso_SONAME)
	$(LN_S) -f $@ $(short_name)

classes = $(patsubst %.java,$(package_dir)/%.class,$(filter %.java, $(BUILT_SOURCES)))

# Because the Java compiler can generate multiple class files from the
# same source .java file, putting all of the classes below will result
# in repeated invocations of javac.  Therefore, an alternative is to
# just depend upon the first class file, and let the Java compiler
# create the rest of them.
$(firstword $(classes)): $(filter %.java, $(BUILT_SOURCES))
	$(JAVAC) $(AM_JFLAGS) $(JAVACFLAGS) -d . $^

$(wordlist 2,$(words $(classes)),$(classes)): $(firstword $(classes))

$(wrappedjar_DATA): MANIFEST.MF

$(wrappedjar_DATA): $(classes)
	$(JAR) cfm $@ MANIFEST.MF $^

install-data-hook:
	cd $(DESTDIR)$(wrappedsodir) && $(LN_S) -f $(wrappedso_DATA) $(wrappedso_SONAME)
	cd $(DESTDIR)$(wrappedsodir) && $(LN_S) -f $(wrappedso_DATA) $(short_name)
	$(mkdir_p) $(DESTDIR)$(javadir) && cd $(DESTDIR)$(javadir) && $(LN_S) -f $(wrappedjardir)/$(wrappedjar_DATA)

uninstall-local:
	-rm -rf $(DESTDIR)$(wrappedsodir)/$(wrappedso_SONAME) $(DESTDIR)$(wrappedsodir)/$(short_name)
	-rm -f $(DESTDIR)$(javadir)/$(wrappedjar_DATA)

MOSTLYCLEANFILES = $(BUILT_SOURCES) $(classes) $(wrappedso_DATA) $(wrappedjar_DATA) $(wrappedso_SONAME) $(short_name)
