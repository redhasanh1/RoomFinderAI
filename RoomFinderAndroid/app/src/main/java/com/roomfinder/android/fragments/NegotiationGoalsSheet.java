package com.roomfinder.android.fragments;

import android.app.Dialog;
import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.google.android.material.bottomsheet.BottomSheetDialog;
import com.google.android.material.bottomsheet.BottomSheetDialogFragment;
import com.google.android.material.button.MaterialButton;
import com.google.android.material.chip.Chip;
import com.google.android.material.chip.ChipGroup;
import com.google.android.material.textfield.TextInputEditText;
import com.roomfinder.android.R;
import com.roomfinder.android.auth.AuthManager;
import com.roomfinder.android.models.NegotiationGoals;

/**
 * The form behind "what should the negotiator argue for".
 *
 * Mirrors NegotiationGoalsSheet on iOS. Android had nothing equivalent, so
 * every negotiation ran with no budget, no target and one fixed manner however
 * the tenant actually wanted it handled.
 *
 * Confirming is a separate act from filling in. The tenant can open this, type
 * a number, change their mind and close it, and nothing reaches a landlord
 * until they press the button - which is the same "lock in" gate the website
 * has. It matters more here because a campaign contacts several landlords at
 * once, so a wrong budget would go out several times before anyone noticed.
 *
 * Show it with:
 *     NegotiationGoalsSheet.show(getParentFragmentManager(), goals -> { ... });
 */
public class NegotiationGoalsSheet extends BottomSheetDialogFragment {

    /** Handed the confirmed goals. Not called if the sheet is dismissed. */
    public interface Listener {
        void onGoalsConfirmed(NegotiationGoals goals);
    }

    private static Listener pendingListener;

    private NegotiationGoals goals;
    private String accountEmail;

    public static void show(@NonNull androidx.fragment.app.FragmentManager fm, Listener listener) {
        pendingListener = listener;
        new NegotiationGoalsSheet().show(fm, "negotiation-goals");
    }

    @NonNull
    @Override
    public Dialog onCreateDialog(@Nullable Bundle savedInstanceState) {
        BottomSheetDialog dialog = (BottomSheetDialog) super.onCreateDialog(savedInstanceState);
        // The sheet is long enough that the collapsed state shows only the
        // first field, which reads as a broken dialog rather than a form.
        dialog.setOnShowListener(d -> {
            View sheet = ((BottomSheetDialog) d)
                    .findViewById(com.google.android.material.R.id.design_bottom_sheet);
            if (sheet != null) {
                com.google.android.material.bottomsheet.BottomSheetBehavior
                        .from(sheet)
                        .setState(com.google.android.material.bottomsheet.BottomSheetBehavior.STATE_EXPANDED);
            }
        });
        return dialog;
    }

    @Nullable
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, @Nullable ViewGroup container,
                             @Nullable Bundle savedInstanceState) {
        return inflater.inflate(R.layout.sheet_negotiation_goals, container, false);
    }

    @Override
    public void onViewCreated(@NonNull View v, @Nullable Bundle savedInstanceState) {
        super.onViewCreated(v, savedInstanceState);

        accountEmail = AuthManager.getInstance(requireContext()).getUserEmail();
        goals = NegotiationGoals.load(requireContext(), accountEmail);

        bind(v);
    }

    private void bind(View v) {
        final TextInputEditText maxRent = v.findViewById(R.id.goalMaxRent);
        final TextInputEditText targetRent = v.findViewById(R.id.goalTargetRent);
        final TextInputEditText city = v.findViewById(R.id.goalCity);
        final TextInputEditText moveIn = v.findViewById(R.id.goalMoveIn);
        final TextInputEditText leaseMonths = v.findViewById(R.id.goalLeaseMonths);
        final TextInputEditText employment = v.findViewById(R.id.goalEmployment);
        final TextInputEditText occupants = v.findViewById(R.id.goalOccupants);
        final TextInputEditText notes = v.findViewById(R.id.goalNotes);

        final ChipGroup assertiveness = v.findViewById(R.id.goalAssertiveness);
        final ChipGroup tone = v.findViewById(R.id.goalTone);
        final android.widget.TextView explainer = v.findViewById(R.id.goalAssertivenessExplainer);

        final Chip parking = v.findViewById(R.id.chipParking);
        final Chip furnished = v.findViewById(R.id.chipFurnished);
        final Chip utilities = v.findViewById(R.id.chipUtilities);
        final Chip pets = v.findViewById(R.id.chipPets);
        final Chip lowerDeposit = v.findViewById(R.id.chipLowerDeposit);
        final Chip firstMonthFree = v.findViewById(R.id.chipFirstMonthFree);
        final Chip nonSmoker = v.findViewById(R.id.chipNonSmoker);

        // Fill in what is already known, so reopening this shows the same
        // answers rather than an empty form the tenant has to redo.
        if (goals.maxRent != null) maxRent.setText(String.valueOf(Math.round(goals.maxRent)));
        if (goals.targetRent != null) targetRent.setText(String.valueOf(Math.round(goals.targetRent)));
        city.setText(goals.city);
        moveIn.setText(goals.moveInDate);
        if (goals.leaseMonths != null) leaseMonths.setText(String.valueOf(goals.leaseMonths));
        employment.setText(goals.employment);
        occupants.setText(goals.occupants);
        notes.setText(goals.notes);

        assertiveness.check(chipIdFor(goals.assertiveness));
        tone.check(chipIdFor(goals.tone));
        explainer.setText(goals.assertiveness.explanation);

        parking.setChecked(goals.parkingNeeded);
        furnished.setChecked(goals.furnished);
        utilities.setChecked(goals.utilitiesIncluded);
        pets.setChecked(goals.petFriendly);
        lowerDeposit.setChecked(goals.askLowerDeposit);
        firstMonthFree.setChecked(goals.askFirstMonthFree);
        nonSmoker.setChecked(goals.nonSmoker);

        // The explanation is the whole point of the three settings - "Firm"
        // alone does not tell anybody what it will do on their behalf.
        assertiveness.setOnCheckedStateChangeListener((group, ids) ->
                explainer.setText(readAssertiveness(group).explanation));

        MaterialButton confirm = v.findViewById(R.id.goalsConfirmButton);
        confirm.setOnClickListener(x -> {
            goals.maxRent = parseDouble(maxRent);
            goals.targetRent = parseDouble(targetRent);
            goals.city = textOf(city);
            goals.moveInDate = textOf(moveIn);
            goals.leaseMonths = parseInt(leaseMonths);
            goals.employment = textOf(employment);
            goals.occupants = textOf(occupants);
            goals.notes = textOf(notes);

            goals.assertiveness = readAssertiveness(assertiveness);
            goals.tone = readTone(tone);

            goals.parkingNeeded = parking.isChecked();
            goals.furnished = furnished.isChecked();
            goals.utilitiesIncluded = utilities.isChecked();
            goals.petFriendly = pets.isChecked();
            goals.askLowerDeposit = lowerDeposit.isChecked();
            goals.askFirstMonthFree = firstMonthFree.isChecked();
            goals.nonSmoker = nonSmoker.isChecked();

            // Without a maximum there is no position to hold, only chat - so
            // this is refused rather than confirmed into a useless state.
            if (!goals.isUsable()) {
                Toast.makeText(requireContext(),
                        "Enter the most you would pay - the negotiator needs a number to hold",
                        Toast.LENGTH_LONG).show();
                maxRent.requestFocus();
                return;
            }

            goals.confirmedAt = System.currentTimeMillis();
            goals.save(requireContext(), accountEmail);

            if (pendingListener != null) {
                pendingListener.onGoalsConfirmed(goals);
            }
            dismiss();
        });
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        // Static, so it would otherwise outlive the sheet and hold the screen
        // that opened it.
        pendingListener = null;
    }

    // ------------------------------------------------------------- plumbing

    private int chipIdFor(NegotiationGoals.Assertiveness a) {
        switch (a) {
            case GENTLE:     return R.id.chipGentle;
            case AGGRESSIVE: return R.id.chipAggressive;
            default:         return R.id.chipFirm;
        }
    }

    private int chipIdFor(NegotiationGoals.Tone t) {
        switch (t) {
            case NEUTRAL:      return R.id.chipNeutral;
            case PROFESSIONAL: return R.id.chipProfessional;
            default:           return R.id.chipFriendly;
        }
    }

    private NegotiationGoals.Assertiveness readAssertiveness(ChipGroup group) {
        int id = group.getCheckedChipId();
        if (id == R.id.chipGentle) return NegotiationGoals.Assertiveness.GENTLE;
        if (id == R.id.chipAggressive) return NegotiationGoals.Assertiveness.AGGRESSIVE;
        return NegotiationGoals.Assertiveness.FIRM;
    }

    private NegotiationGoals.Tone readTone(ChipGroup group) {
        int id = group.getCheckedChipId();
        if (id == R.id.chipNeutral) return NegotiationGoals.Tone.NEUTRAL;
        if (id == R.id.chipProfessional) return NegotiationGoals.Tone.PROFESSIONAL;
        return NegotiationGoals.Tone.FRIENDLY;
    }

    private String textOf(TextInputEditText field) {
        return field.getText() == null ? "" : field.getText().toString().trim();
    }

    private Double parseDouble(TextInputEditText field) {
        String raw = textOf(field);
        if (raw.isEmpty()) return null;
        try {
            return Double.parseDouble(raw);
        } catch (NumberFormatException e) {
            return null;
        }
    }

    private Integer parseInt(TextInputEditText field) {
        String raw = textOf(field);
        if (raw.isEmpty()) return null;
        try {
            return Integer.parseInt(raw);
        } catch (NumberFormatException e) {
            return null;
        }
    }
}
