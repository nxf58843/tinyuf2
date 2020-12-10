SELF_OUTNAME = update-tinyuf2-$(BOARD)

SELF_SRC_C += $(subst $(TOP)/,,$(wildcard $(TOP)/self_update/*.c))
SELF_SRC_C += self_update/$(OUTNAME).c

SELF_BUILD_OBJ = $(BUILD)/self_obj
SELF_OBJ += $(addprefix $(SELF_BUILD_OBJ)/, $(SRC_S:.s=.o))
SELF_OBJ += $(addprefix $(SELF_BUILD_OBJ)/, $(PORT_SRC_C:.c=.o))
SELF_OBJ += $(addprefix $(SELF_BUILD_OBJ)/, $(SELF_SRC_C:.c=.o))

SELF_OBJ_DIRS = $(sort $(dir $(SELF_OBJ)))
$(SELF_OBJ): | $(SELF_OBJ_DIRS)
$(SELF_OBJ_DIRS):
	@$(MKDIR) -p $@

self-update: $(SELF_BUILD_OBJ)/$(SELF_OUTNAME).uf2

$(SELF_BUILD_OBJ)/$(SELF_OUTNAME).uf2: $(SELF_BUILD_OBJ)/$(SELF_OUTNAME).hex
	@echo CREATE $@
	$(PYTHON3) $(TOP)/lib/uf2/utils/uf2conv.py -f $(UF2_FAMILY_ID) -c -o $@ $^

$(SELF_BUILD_OBJ)/$(SELF_OUTNAME).elf: $(SELF_OBJ)
	@echo LINK $@
	@$(CC) -o $@ $(SELF_LDFLAGS) $^ -Wl,--start-group $(LIBS) -Wl,--end-group

#-------------- Compile Rules --------------

# We set vpath to point to the top of the tree so that the source files
# can be located. By following this scheme, it allows a single build rule
# to be used to compile all .c files.
$(SELF_BUILD_OBJ)/%.o: %.c
	@echo CC $(notdir $@)
	@$(CC) $(CFLAGS) -DTINYUF2_SELF_UPDATE -c -MD -o $@ $<
	@# The following fixes the dependency file.
	@# See http://make.paulandlesley.org/autodep.html for details.
	@# Regex adjusted from the above to play better with Windows paths, etc.
	@$(CP) $(@:.o=.d) $(@:.o=.P); \
	  $(SED) -e 's/#.*//' -e 's/^.*:  *//' -e 's/ *\\$$//' \
	      -e '/^$$/ d' -e 's/$$/ :/' < $(@:.o=.d) >> $(@:.o=.P); \
	  $(RM) $(@:.o=.d)

# ASM sources lower case .s
vpath %.s . $(TOP)
$(SELF_BUILD_OBJ)/%.o: %.s
	@echo AS $(notdir $@)
	@$(CC) -x assembler-with-cpp $(ASFLAGS) -c -o $@ $<

# ASM sources upper case .S
vpath %.S . $(TOP)
$(SELF_BUILD_OBJ)/%.o: %.S
	@echo AS $(notdir $@)
	@$(CC) -x assembler-with-cpp $(ASFLAGS) -c -o $@ $<

#-------------- Artifacts --------------
$(BIN):
	@$(MKDIR) -p $@

copy-artifact: $(BIN)
copy-artifact: $(BUILD)/$(OUTNAME).bin $(BUILD)/$(OUTNAME).hex $(SELF_BUILD_OBJ)/$(SELF_OUTNAME).uf2
	@$(CP) $(BUILD)/$(OUTNAME).bin $(BIN)
	@$(CP) $(BUILD)/$(OUTNAME).hex $(BIN)
	@$(CP) $(SELF_BUILD_OBJ)/$(SELF_OUTNAME).uf2 $(BIN)
