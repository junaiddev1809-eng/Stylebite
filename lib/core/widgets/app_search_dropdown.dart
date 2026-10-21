import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:stylebite/core/widgets/app_hero_icon.dart';

import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';

class CommonSearchableDropDown extends StatelessWidget {
  const CommonSearchableDropDown({
    super.key,
    required this.itemList,
    required this.hintText,
    required this.hintTextOfField,
    this.onChangeValue,
    this.selectedItem,
    this.isMultiSelect = false,
    this.selectedItems = const <String>[],
    this.onChangeMultiValue,
    this.fontsize = 14,
    this.dropdownTileColor = Colors.white,
  });

  final List<String> itemList;
  final Function(String?)? onChangeValue;
  final String hintText;
  final String hintTextOfField;
  final String? selectedItem;
  final bool isMultiSelect;
  final List<String> selectedItems;
  final Function(List<String>)? onChangeMultiValue;
  final double fontsize;
  final Color dropdownTileColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: isMultiSelect ? null : 50,
      child: isMultiSelect
          ? DropdownSearch<String>.multiSelection(
              popupProps: _popupPropsMulti(),
              items: itemList,
              dropdownDecoratorProps: _decoratorProps(),
              onChanged: onChangeMultiValue,
              dropdownButtonProps: _buttonProps(),
              selectedItems: selectedItems,
            )
          : DropdownSearch<String>(
              popupProps: _popupPropsSingle(),
              items: itemList,
              dropdownDecoratorProps: _decoratorProps(),
              onChanged: onChangeValue,
              dropdownButtonProps: _buttonProps(),
              selectedItem: selectedItem?.isNotEmpty == true ? selectedItem : null,
            ),
    );
  }

  PopupProps<String> _popupPropsSingle() {
    return PopupProps.menu(
      showSelectedItems: true,
      showSearchBox: true,
      menuProps: MenuProps(backgroundColor: dropdownTileColor),
      searchFieldProps: TextFieldProps(
        style: AppFonts.beVietnam(size: fontsize, color: AppColors.text),
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          hintText: hintTextOfField,
          hintStyle: AppFonts.beVietnam(size: fontsize, color: AppColors.hintText),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.primary, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.18)),
          ),
          contentPadding: const EdgeInsets.only(left: 20),
          filled: true,
          fillColor: const Color(0xFFF4F1F0),
        ),
      ),
      itemBuilder: (context, item, isSelected) {
        return Container(
          color: dropdownTileColor,
          child: ListTile(
            title: Text(
              item,
              style: AppFonts.beVietnam(
                size: 14,
                color: isSelected ? AppColors.primary : AppColors.text,
              ),
            ),
          ),
        );
      },
    );
  }

  PopupPropsMultiSelection<String> _popupPropsMulti() {
    return PopupPropsMultiSelection.menu(
      showSelectedItems: true,
      showSearchBox: true,
      menuProps: MenuProps(backgroundColor: dropdownTileColor),
      searchFieldProps: TextFieldProps(
        style: AppFonts.beVietnam(size: fontsize, color: AppColors.text),
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          hintText: hintTextOfField,
          hintStyle: AppFonts.beVietnam(size: fontsize, color: AppColors.hintText),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.primary, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.18)),
          ),
          contentPadding: const EdgeInsets.only(left: 20),
          filled: true,
          fillColor: const Color(0xFFF4F1F0),
        ),
      ),
      itemBuilder: (context, item, isSelected) {
        return Container(
          color: dropdownTileColor,
          child: ListTile(
            title: Text(
              item,
              style: AppFonts.beVietnam(
                size: 14,
                color: isSelected ? AppColors.primary : AppColors.text,
              ),
            ),
          ),
        );
      },
    );
  }

  DropDownDecoratorProps _decoratorProps() {
    return DropDownDecoratorProps(
      baseStyle: AppFonts.beVietnam(size: fontsize, color: AppColors.text),
      dropdownSearchDecoration: InputDecoration(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        hintText: hintText,
        hintStyle: AppFonts.beVietnam(size: fontsize, color: AppColors.hintText),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.18)),
        ),
        contentPadding: const EdgeInsets.only(left: 20),
        filled: true,
        fillColor: const Color(0xFFF4F1F0),
      ),
    );
  }

  DropdownButtonProps _buttonProps() {
    return const DropdownButtonProps(
      icon: AppHeroIconData(
        Icons.keyboard_arrow_down_rounded,
        color: AppColors.hintText,
        size: 25,
      ),
    );
  }
}
