# Integrated Circuits

An integrated circuit is a circuit you configure in Brain Visualizer. On **Add Circuit**, it is the tile with a gold **IC** chip on the top-right corner of its image. Hover the chip for the short explanation. Click the image or the chip to open its configuration window.

The other tiles on that window, such as Logic AND and Logic OR, are genomes or connectomes. Choosing one of those uploads the packaged circuit. Choosing an integrated circuit does not. You set it up for the brain circuit you already have open.

A [brain circuit](brain_circuits.md) is the container: a named place that holds cortical areas and smaller circuits. An integrated circuit is something you build inside that container. The integrated circuit available now is the **Classifier**.

## What a Classifier Does

A classifier learns a correspondence between a pattern and a label, then reports detections when that pattern appears again.

It is made of cortical areas in the brain circuit where you create it:

- **Kernel memory** and **class memory** are memory areas created with the classifier. Their names are the classifier name plus `_kernel_mem` and `_class_mem`. Kernel memory holds the patterns. Class memory holds the labels. An associative mapping binds the two.
- The **kernel area**, **class area**, or **mask** is a cortical area you already have. You choose it when you configure the classifier. It is not created for you, and deleting the classifier does not delete it.
- Each image field you connect later gets its own **detection area**. That area is where the classifier reports a match for that field.

Two training modes decide how a pattern and a label are paired. Recall uses the same geometry you trained with.

**Kernel training** takes one sample from the kernel area and one label from the class area on each burst. Use it when both the pattern and the label are already single areas.

**Scanner training** slides a kernel of the size you set across every image field you connect, and takes the label for each window from the mask area. The mask is read across its width and height. Its depth is the number of classes. The kernel's depth must match the depth of each field you connect. Use it when the thing to classify is a region inside a larger field, rather than the whole area.

## How It Appears

In **Circuit Builder** the classifier is a teal node in the circuit where you created it. Mappings you draw land on that node. Kernel memory and class memory are not drawn as separate nodes. Each detection area is drawn, with a line back to the classifier. That line shows which field the area belongs to. It is not a mapping, and clicking it does not open the mapping editor.

In **Brain Monitor** kernel memory is the stamp: the cortical volume for the classifier. Click the stamp to select the classifier. Class memory is not drawn. A detection area is an ordinary cortical volume.

**Memory Areas** lists kernel memory and class memory under those names. **Interconnect Areas** lists each detection area.

## Add a Classifier

1. Open the brain circuit that should contain it.
2. Hover **Circuits** and click **+**.
3. Choose **Classifier**.

The create window opens for that circuit. Its instruction is to choose kernel training or scanner training, and to connect image fields after the classifier exists.

### Create window

**Classifier name** is required. If that name is already used, the form reports "A classifier using this name already exists."

**3D Position** is the stamp's location. When a Brain Monitor for this circuit is open, a preview stamp appears there. Move the preview with the gizmo, or type the position. The two stay in step.

**Training mode** changes the rest of the form.

- Kernel training asks for a **Kernel area** and a **Class area**.
- Scanner training asks for a **Mask area** and a **Kernel size**. Each axis of the kernel size must be at least 1.

The area menus list non-memory areas in this circuit. They omit memory areas, detection areas, and areas a classifier already owns. Kernel training needs both a kernel area and a class area. Scanner training needs a mask in this circuit.

**Create Classifier** builds the assembly and closes the window. A problem stays on the form in red, and the window stays open.

## Connect an Image Field

Connect fields after the classifier exists. Each field is one image the classifier will scan, and each field receives its own detection area.

1. Right-click the source area and choose **Quick Connect**. The source must be an interconnect area or a custom area.
2. Click the classifier: its node in Circuit Builder, or its stamp in Brain Monitor.
3. The connectivity rule is set to **Classifier**. There is no other rule to choose.
4. Confirm.

The detection area for that field then appears. In Brain Monitor the connection guide ends on the center of the stamp, unless another cortical volume lies in front of the stamp.

Quick Connect will not start from a memory area, a detection area, or an area the classifier already owns. In that case the window tells you that a classifier mapping starts from an interconnect area.

## Edit a Classifier

Right-click the classifier and choose **Details**. The button tooltip is **Classifier properties**. This opens the classifier editor, not Cortical Area Details and not the circuit editor.

If the editor is already open, selecting a different classifier loads that classifier. Selecting the same one again refreshes the neuron counts.

**Update** applies the settings in the main form and closes the editor. **Cancel** closes it without applying those settings. The collapsed sections below the form have their own **Apply Update** buttons and are not part of that commit.

### Main form

- **Classifier ID** identifies the classifier. It cannot be edited.
- **Classifier Name** is the name shown on the node and used in the memory-area names.
- **Parent Circuit** is the brain circuit that contains the classifier. Change it here. The quick menu has no separate command for moving a classifier into another circuit.
- **3D Position** moves the stamp.
- **Training Mode** offers the same choice as creation. Kernel training still requires a kernel area and a class area. Scanner training still requires a mask area and a kernel size. Changing the mode replaces the inputs used by the previous mode.

### Neuron counts

**Kernel Memory Neurons** and **Class Memory Neurons** are read-only. When FEAGI can report live counts, the field shows the total and the short-term / long-term split, as `(ST: … | LT: …)`. Hover the field for the three numbers written out.

### Kernel memory, class memory, and the associative mapping

Three sections start collapsed. **Apply Update** in a section stays disabled until you change a value in that section.

**Kernel Memory Area** and **Class Memory Area** edit the memory parameters of those two areas: Initial Neuron Lifespan, Lifespan Growth Rate, Longterm Memory Threshold, Temporal Depth, and MP Learning. Those parameters are the same ones documented for any memory area in [Cortical Area Details](cortical_area_details.md).

**Associative Memory Parameters** edits the plasticity of the mapping from kernel memory to class memory: Plasticity Window, Plasticity Constant, LTP Multiplier, and LTD Multiplier.

If the memory area or the associative mapping is not available, the section says so and **Apply Update** stays disabled.

## Move or Delete

Right-click the classifier.

- From Circuit Builder, **Relocate this classifier (2D)** follows the mouse. Left-click to commit the new position.
- From Brain Monitor, **Relocate this classifier (3D gizmo)** moves the stamp. A Brain Monitor for the classifier's circuit must be open.
- **Delete this classifier...** deletes the classifier, its kernel memory, its class memory, and its detection areas. The kernel, class, and mask areas you selected are left in place.

The classifier quick menu does not include Open 3D Tab, clone, or Quick Connect. To inspect the stamp, open a Brain Monitor on the circuit that contains the classifier.

## Related Topics

- [Brain Circuits](brain_circuits.md) - Containers that hold a classifier
- [Cortical Area Details](cortical_area_details.md) - Memory parameters used by kernel and class memory
- [Circuit Builder](circuit_builder.md) - The 2D node
- [Brain Monitor](brain_monitor.md) - The stamp
- [Mapping Connections](mapping_connections.md) - Quick Connect
- [Quick Menu](quick_menu.md) - Details, relocate, and delete

[Back to Overview](index.md)
