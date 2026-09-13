"""Ordered, supplied factor/action panels with a continuous adjacent braid.

This is presentation data, not a mapping-class or factorization engine. In
particular an exponent labels a supplied factor; it does not apply an action to
its support or manufacture a braid lift.
"""
from dataclasses import dataclass, replace

from .model import _number
from .primitives import Drawing, Path, Text
from .visuals import (Panel, Figure, BraidDiagram, RAINBOW, _shift,
                      _braid_paths, _braid_labels)


@dataclass(frozen=True)
class FactorPanel:
    """One stable factor ID and its supplied support panel.

    braid_word, when present, is the COMPLETE signed crossing block for this
    factor, in traversal order, including any power or inverse already supplied
    by the caller. () explicitly supplies a straight block; None supplies none.
    state is an optional supplied image AFTER this factor, not a computed image.
    group is a plain-text label for a contiguous block of factors.
    """
    id: str
    support: Panel
    exponent: int = 1
    braid_word: object = None
    state: object = None
    group: str = ''

    def __post_init__(self):
        if not isinstance(self.id, str) or not self.id.strip() or self.id.splitlines() != [self.id]:
            raise ValueError('factor ID must be nonempty single-line text')
        if not isinstance(self.support, Panel):
            raise TypeError('support must be a Panel')
        if type(self.exponent) is not int or self.exponent == 0:
            raise ValueError('factor exponent must be a nonzero integer')
        if self.braid_word is not None:
            object.__setattr__(self, 'braid_word', tuple(self.braid_word))
            if any(type(i) is not int or i == 0 for i in self.braid_word):
                raise ValueError('braid_word must contain nonzero signed integer positions')
        if self.state is not None and not isinstance(self.state, Panel):
            raise TypeError('state must be a Panel or None')
        if not isinstance(self.group, str) or (self.group and
                (not self.group.strip() or self.group.splitlines() != [self.group])):
            raise ValueError('group must be single-line text')

    @property
    def label(self):
        """An ID/power label; labels are plain text in both exports."""
        return f'[{self.id}]' + (f'^{self.exponent}' if self.exponent != 1 else '')


@dataclass(frozen=True)
class FactorizationDiagram:
    """Draw factors in APPLICATION order, bottom to top by default.

    For factors (a, b), a is applied first and the right-to-left product is b*a,
    regardless of display direction. IDs, support geometry and colors are never
    reassigned or simplified. Repeated support curves need distinct factor IDs.

    Set strands to show a continuous adjacent braid; then every factor must
    supply its full braid_word, including () for an identity block. This draws
    an asserted correspondence, without checking a lift or equality. To show
    action states, supply initial_state AND a state for every factor.
    """
    factors: tuple
    strands: object = None
    initial_state: object = None
    direction: str = 'bottom-to-top'
    braid_spacing: float = 30
    colors: tuple = RAINBOW
    gap: float = 24

    def __post_init__(self):
        object.__setattr__(self, 'factors', tuple(self.factors))
        if any(not isinstance(f, FactorPanel) for f in self.factors):
            raise TypeError('factors must contain FactorPanel records')
        if len({f.id for f in self.factors}) != len(self.factors):
            raise ValueError('factor IDs must be distinct; supports may repeat')
        if self.direction not in ('bottom-to-top', 'top-to-bottom'):
            raise ValueError('direction must be bottom-to-top or top-to-bottom')
        _number(self.gap, 'gap')
        if self.gap < 0:
            raise ValueError('gap must be nonnegative')
        # Validate even a braid-free diagram's options, so replacing fields does
        # not expose a previously hidden invalid color/spacing configuration.
        object.__setattr__(self, 'colors', tuple(self.colors))
        BraidDiagram(1 if self.strands is None else self.strands,
                     spacing=self.braid_spacing, colors=self.colors)
        if self.strands is None:
            if any(f.braid_word is not None for f in self.factors):
                raise ValueError('set strands when supplying braid words')
        else:
            for factor in self.factors:
                if factor.braid_word is None:
                    raise ValueError('every factor needs an explicit braid_word when strands is set')
                BraidDiagram(self.strands, factor.braid_word)
        if self.initial_state is not None and not isinstance(self.initial_state, Panel):
            raise TypeError('initial_state must be a Panel or None')
        if any((f.state is not None) != (self.initial_state is not None) for f in self.factors):
            raise ValueError('supply initial_state and every factor state together, or omit all states')
        # A group name identifies one block. Reject disjoint occurrences instead
        # of suggesting that separated factors form one contiguous subword.
        seen, previous = set(), ''
        for factor in self.factors:
            if factor.group and factor.group != previous:
                if factor.group in seen:
                    raise ValueError('each group must occupy a contiguous block')
                seen.add(factor.group)
            previous = factor.group

    @property
    def factor_ids(self):
        return tuple(f.id for f in self.factors)

    @property
    def product_label(self):
        return ' * '.join(f.label for f in reversed(self.factors)) or '1'

    def drawing(self, style):
        from .layout import layout

        def panel_drawing(panel, heading):
            title = heading + ('\n'+panel.title if panel.title else '')
            return layout(Figure(((replace(panel, title=title),),), gap=0), style)

        empty = Drawing(0, 0, ())
        rows, words, groups = [], [], []
        if self.initial_state is not None:
            rows.append((empty, panel_drawing(self.initial_state, 'Initial state (supplied)')))
            words.append(())
            groups.append('')
        for i, factor in enumerate(self.factors):
            support = panel_drawing(factor.support, f'{i+1}. {factor.label}')
            state = (panel_drawing(factor.state, f'After {factor.label} (supplied)')
                     if factor.state is not None else empty)
            rows.append((support, state))
            words.append(factor.braid_word or ())
            groups.append(factor.group)
        if not rows:
            rows.append((Drawing(140, 64, (), texts=(Text(0, 0, 'Empty factor sequence', style.outline_color, 10),)), empty))
            words.append(())
            groups.append('')

        support_width = max(d[0].width for d in rows)
        state_width = max(d[1].width for d in rows)
        group_width = max((len(g)*7+24 for g in groups if g), default=0)
        column_gap = 24
        braid_width = (max(self.braid_spacing, (self.strands-1)*self.braid_spacing)+32
                       if self.strands is not None else 0)
        width = group_width+support_width
        if state_width:
            width += column_gap+state_width
        if braid_width:
            width += column_gap+braid_width
        # Long supplied crossing blocks get more height, never compressed
        # underpasses. Support panels retain their native geometry and scale.
        step = max(36, style.curve_width*8)
        heights = [max(a.height, b.height, max(1, len(word))*step if braid_width else 36)
                   for (a, b), word in zip(rows, words)]
        body_height = sum(heights)+self.gap*(len(rows)-1)
        sign = 1 if self.direction == 'bottom-to-top' else -1
        edge = -sign*body_height/2
        support_x = -width/2+group_width+support_width/2
        state_x = support_x+support_width/2+column_gap+state_width/2
        braid_x = width/2-braid_width/2
        ellipses, paths, texts, bands = [], [], [], []
        crossings, ys = [], [edge]
        for index, ((support, state), word, height) in enumerate(zip(rows, words, heights)):
            exit_edge = edge+sign*height
            center = (edge+exit_edge)/2
            for drawing, x in ((support, support_x), (state, state_x)):
                moved = _shift(drawing, x, center)
                ellipses.extend(moved.ellipses)
                paths.extend(moved.paths)
                texts.extend(moved.texts)
            if word:
                # Keep crossings compact at the row center. Stretching a single
                # crossing to the height of a surface panel makes its underpass
                # gap look like a broken strand instead of a local crossing.
                inset = (height-len(word)*step)/2
                start = edge+sign*inset
                if inset > 0:
                    crossings.append(None)
                    ys.append(start)
                crossings.extend(word)
                ys.extend(start+sign*step*(i+1) for i in range(len(word)))
                if inset > 0:
                    crossings.append(None)
                    ys.append(exit_edge)
            else:
                crossings.append(None)
                ys.append(exit_edge)
            bands.append((edge, exit_edge))
            edge = exit_edge
            if index+1 < len(rows) and self.gap:
                edge += sign*self.gap
                crossings.append(None)
                ys.append(edge)

        if braid_width:
            braid_paths, order = _braid_paths(self.strands, crossings, ys,
                                             self.braid_spacing, self.colors, style)
            labels = _braid_labels(self.strands, order, ys[0], ys[-1], self.braid_spacing, self.colors)
            braid = _shift(Drawing(braid_width, body_height, (), braid_paths, labels), braid_x, 0)
            paths.extend(braid.paths)
            texts.extend(braid.texts)
            # Short ticks outside the strands show exactly which row each
            # supplied block occupies, without drawing extra strand crossings.
            x = braid_x+braid_width/2-4
            for a, b in bands:
                paths.append(Path((('M', x-6, a), ('L', x, a), ('L', x, b), ('L', x-6, b)),
                                  style.outline_color, .7, 'factor-braid-block'))

        i = 0
        while i < len(groups):
            group = groups[i]
            end = i+1
            while group and end < len(groups) and groups[end] == group:
                end += 1
            if group:
                a, b = bands[i][0], bands[end-1][1]
                x = -width/2+group_width-10
                paths.append(Path((('M', x+5, a), ('L', x, a), ('L', x, b), ('L', x+5, b)),
                                  style.outline_color, 1, 'factor-group'))
                texts.append(Text(-width/2+(group_width-16)/2, (a+b)/2-3, group, style.outline_color, 10))
            i = end

        # Wrap long expressions without rescaling the mathematical panels.
        # Break only BETWEEN factor labels.
        limit = max(24, int(width/7))
        lines = ['Product (right-to-left):']
        current = ''
        for token in [f.label for f in reversed(self.factors)] or ['1']:
            addition = (' * ' if current else '')+token
            if current and len(current+addition) > limit:
                lines.append(current+' *')
                current = token
            else:
                current += addition
        lines.extend((current, 'Application order: '+self.direction))
        for i, line in enumerate(lines):
            texts.append(Text(0, body_height/2+38+16*(len(lines)-1-i), line, style.outline_color, 11))
        footnote = 'Supplied supports' + (' / states' if state_width else '')
        footnote += (' / braid blocks' if braid_width else '') + '; no action or equality checked.'
        texts.append(Text(0, -body_height/2-38, footnote, style.outline_color, 10))
        width = max(width, max(map(len, lines))*7, len(footnote)*6)
        # Center the asymmetric header/footer frame without altering any panel.
        top_space = 54+16*(len(lines)-1)
        bottom_space = 54
        drawing = Drawing(width+2*style.padding, body_height+top_space+bottom_space+2*style.padding,
                          tuple(ellipses), tuple(paths), tuple(texts))
        return _shift(drawing, 0, (bottom_space-top_space)/2)

    def _repr_svg_(self):
        from .svg import render_svg
        return render_svg(self)
