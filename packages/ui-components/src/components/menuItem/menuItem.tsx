import React from 'react';
import styled from 'styled-components';

// import {IconType} from '../../';

export type MenuItemProps = {
  /**
   * Icon to prepend to the Menu item text
   */
  //TODO: set up proper type
  icon: any;

  /**
   * Whether the current item is active
   */
  isActive: boolean;

  /**
   * Menu item text
   */
  label: string;

  onClick?: () => void;
};

export const MenuItem: React.FC<MenuItemProps> = ({
  icon,
  isActive = false,
  label,
  onClick,
}) => {
  return (
    <Container onClick={onClick} isActive={isActive} data-testid="menuItem">
      {isActive && <IconContainer>{icon}</IconContainer>}
      <Label>{label}</Label>
    </Container>
  );
};

type ContainerProp = {isActive: boolean};
const Container = styled.button.attrs(({isActive}: ContainerProp) => ({
  className: `flex items-center px-1.5 py-2 space-x-1.5 ${
    isActive ? 'text-primary-500 bg-ui-0' : 'text-ui-600'
  }  active:text-primary-500 hover:text-ui-800 focus:bg-ui-0 rounded-xl`,
}))<ContainerProp>`
  cursor: pointer;
`;

const IconContainer = styled.div.attrs({
  className: 'flex justify-center items-center w-2 h-2',
})``;

const Label = styled.p``;
